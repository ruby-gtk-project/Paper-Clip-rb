# frozen_string_literal: true

require 'adwaita'
require 'cairo'
require 'fileutils'
require 'tmpdir'

require_relative 'thread_manager'

module PaperClip
  # Thumbnailer rasterises a PDF page into a texture, off the main loop.
  #
  # Ported from upstream's src/Services/Thumbnailer.vala: one shared
  # instance, a `max_size` its caller sets, and a render whose result comes
  # back either as raw memory or as a downscaled PNG depending on how big the
  # page is. The threshold, the step loop, the cache path and the
  # memory-format choice are all upstream's.
  #
  # Why either-or at all: a page whose pixel count is far beyond the size it
  # will be shown at would mean carrying tens of megabytes of surface around
  # to draw a 350-pixel image, so such a page goes out to a PNG and comes
  # back through `from_file_at_size`, which decodes it at the smaller size
  # instead of decoding and then shrinking. A page near the display size is
  # handed over as the memory it already is, with no file touched.
  #
  # The render runs on ThreadManager's single worker, as upstream's does on
  # its single-worker ThreadPool. For that to be worth anything in Ruby the
  # GVL has to be released across the C call, which is why
  # `Poppler::Loader#should_unlock_gvl?` names `render` — without it the
  # worker would hold the interpreter and stall the frame it was meant to
  # save.
  #
  # Upstream awaits three times (render, then one of the two loads); here the
  # render and the load are one job on the same worker. The two shapes are
  # indistinguishable from the main loop's side — one worker, serialised, the
  # result delivered on the main loop — and one job means a surface cannot be
  # collected between the render and the read of its bytes.
  class Thumbnailer
    Error = Class.new(StandardError)
    ExportError = Class.new(Error)
    CacheError = Class.new(Error)

    # How much bigger than the display area a page may be before it is sent
    # out through a downscaled PNG instead of straight into memory.
    AREA_THRESHOLD = 2.5

    # Upstream steps the factor from 0.1 up by 0.1 for as long as it is below
    # 0.8, and a loop that never breaks early leaves it at the limit
    # (src/Services/Thumbnailer.vala:83-91).
    SCALE_STEPS = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7].freeze
    SCALE_LIMIT = 0.8

    CACHE_DIRECTORY = 'thumbnails'

    # Upstream's get_default (src/Services/Thumbnailer.vala:34-39). The
    # instance is shared because `max_size` is a property of the renderer
    # there, not of a call, and every thumbnail in the app wants the same one.
    def self.default = @default ||= new

    attr_accessor :max_size

    # Upstream's field has no initialiser, so an int property starts at zero
    # and the caller is expected to set it — DocumentThumbnail does, in its
    # construct block.
    def initialize
      @max_size = 0
    end

    # Renders `page` and hands the texture to `on_done` on the main loop, or
    # the exception to `on_error`. The surface is allocated here rather than
    # on the worker, as upstream allocates it before its first yield: the
    # page's size is a cheap read, and the worker should start on the render.
    def create_thumbnail(page, basename, on_done:, on_error:)
      surface_for(page).then do |surface|
        ThreadManager.run_in_thread(on_done: on_done, on_error: on_error) do
          render(page, surface)
          load_texture(surface, basename)
        end
      end
    end

    # Cairo's ARGB32 is a native-endian 32-bit word, so the same bytes are
    # BGRA on a little-endian machine and ARGB on a big-endian one. Upstream
    # picks between the two formats from BYTE_ORDER for exactly that reason
    # (src/Services/Thumbnailer.vala:19-30), and caches the answer.
    def default_format
      @default_format ||= native_format
    end

    private

      def surface_for(page)
        page.size.then do |width, height|
          Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, width.to_i, height.to_i)
        end
      end

      # The context is destroyed with the block, which flushes the surface;
      # the explicit flush is what makes `surface.data` below safe to read
      # whether or not that destruction has happened yet.
      def render(page, surface)
        Cairo::Context.new(surface) { |context| page.render(context) }
        surface.flush
      end

      def load_texture(surface, basename)
        if image_area(surface) >= max_area
          load_scaled(surface, basename)
        else
          load_memory(surface)
        end
      end

      def max_area = max_size * max_size * AREA_THRESHOLD
      def image_area(surface) = surface.width * surface.height

      # `from_file_at_size` decodes the PNG at the reduced size, which is the
      # point of having written it out: the full-size pixels never have to be
      # held in memory a second time.
      def load_scaled(surface, basename)
        export(surface, basename).then do |save_path|
          scale_factor(surface).then do |factor|
            GdkPixbuf::Pixbuf.new(
              file:   save_path,
              width:  (surface.width * factor).to_i,
              height: (surface.height * factor).to_i,
            ).then { |pixbuf| Gdk::Texture.new(pixbuf) }
          end
        end
      end

      # Upstream multiplies the pixel count by the factor itself rather than
      # by its square (src/Services/Thumbnailer.vala:87), so the factor this
      # settles on is larger than an area-preserving one would be. Kept as
      # upstream has it: the loop's job is to stop growing the thumbnail once
      # it is comfortably past the display area, and it does that.
      def scale_factor(surface)
        SCALE_STEPS.find { |factor| image_area(surface) * factor >= max_area } || SCALE_LIMIT
      end

      # Cairo::WriteError — the exception `write_to_png` actually raises when
      # the write itself fails, e.g. a missing parent directory or a full
      # disk — is a Ruby IOError, not a Cairo::Error: the cairo-ruby bindings
      # give each libcairo status code its own class, and only `WriteError`
      # and `ReadError` are also IOErrors. `Cairo::Error` alone let a real
      # write failure straight through unrescued; nothing drove this path
      # until it was forced, which is how that went unnoticed.
      def export(surface, basename)
        create_cache_file(basename).tap do |save_path|
          surface.write_to_png(save_path)
        rescue Cairo::Error, IOError, SystemCallError => e
          raise ExportError, "Failed to export #{save_path}: #{e.message}"
        end
      end

      # Upstream also creates the file here when it does not exist
      # (src/Services/Thumbnailer.vala:114-117), which write_to_png would do
      # a line later anyway; only the directory has to exist in advance.
      def create_cache_file(basename)
        cache_directory.then { |directory| ::File.join(directory, "#{basename}.png") }
      end

      # 0o700 and not upstream's 0o777: this is a directory in a shared
      # /tmp, named after the open document, and a world-writable one there
      # is a file another user can replace between the write and the read.
      # Document's copies directory is 0o700 for the same reason.
      def cache_directory
        ::File.join(Dir.tmpdir, CACHE_DIRECTORY).tap do |directory|
          FileUtils.mkdir_p(directory, mode: 0o700)
        rescue SystemCallError => e
          raise CacheError, "Unable to create tmp path #{directory}: #{e.message}"
        end
      end

      # Upstream copies the surface's bytes into a buffer of its own before
      # wrapping them, because the surface owns them and outlives nothing
      # (src/Services/Thumbnailer.vala:135-139). `surface.data` is already
      # that copy — it builds a new Ruby string — so the texture never points
      # into a surface that may have been freed.
      def load_memory(surface)
        GLib::Bytes.new(surface.data).then do |bytes|
          Gdk::MemoryTexture.new(
            surface.width,
            surface.height,
            default_format,
            bytes,
            surface.stride,
          )
        end
      end

      def native_format
        if little_endian?
          :b8g8r8a8_premultiplied
        else
          :a8r8g8b8_premultiplied
        end
      end

      # 'S' is a native-endian short, 'v' a little-endian one.
      def little_endian? = [1].pack('S') == [1].pack('v')
  end
end

# frozen_string_literal: true

require 'adwaita'

require_relative 'thumbnailer'

module PaperClip
  # DocumentThumbnail is the preview of page one above the filename.
  #
  # A direct port of upstream's src/DocumentThumbnail.vala: a bin holding one
  # image, whose paintable is a snapshot of the rendered page drawn over a
  # white rectangle and scaled to fit MAX_SIZE.
  #
  # The white rectangle is not decoration. A PDF page with a transparent
  # background renders as transparent pixels, and without something opaque
  # underneath the thumbnail would show whatever is behind the window —
  # which, for a page of black text, means the text may be invisible.
  #
  # Upstream's destructor clears the image to drop its reference to the
  # texture; a Ruby object has no destructor to port, and dropping the last
  # reference to the paintable is what the garbage collector is for.
  class DocumentThumbnail
    MAX_SIZE = 350

    DROPSHADOW_CLASS = 'icon-dropshadow'

    # The opaque backing for a transparent page.
    WHITE = Gdk::RGBA.new(
      1,
      1,
      1,
      1,
    )

    def build
      bin.tap { |b| b.child = image }
    end

    def update(document)
      image.clear
      document.get_page_for_index(0).then do |page|
        if page
          generate(page, document.basename)
        end
      end
    end

    def bin = @bin ||= Adwaita::Bin.new

    # The pixel size is what the image occupies before a paintable arrives,
    # so the page below does not jump up by 350 pixels when one does.
    def image
      @image ||= Gtk::Image.new.tap do |img|
        img.add_css_class(DROPSHADOW_CLASS)
        img.pixel_size = MAX_SIZE / 2
        img.margin_top = 12
      end
    end

    def thumbnailer
      @thumbnailer ||= Thumbnailer.default.tap { |service| service.max_size = MAX_SIZE }
    end

    private

      # Upstream logs the failure and leaves the image cleared
      # (src/DocumentThumbnail.vala:58-61), so a page that will not render
      # costs the preview and nothing else.
      def generate(page, basename)
        thumbnailer.create_thumbnail(
          page,
          basename,
          on_done:  ->(texture) { image.paintable = scale(texture) },
          on_error: ->(error) { warn(error.message) },
        )
      end

      def scale(texture)
        scaled_size(texture).then do |width, height|
          Graphene::Rect.new(
            0,
            0,
            width.floor,
            height.floor,
          ).then do |rectangle|
            Gtk::Snapshot.new.tap do |snapshot|
              snapshot.append_color(WHITE, rectangle)
              snapshot.append_scaled_texture(texture, filter(texture, width, height), rectangle)
            end.to_paintable(nil)
          end
        end
      end

      # Upstream assigns LINEAR and then overwrites it in both branches
      # (src/DocumentThumbnail.vala:69-74), so LINEAR never reaches the
      # snapshot and the real choice is these two: scaling a page up keeps
      # its edges crisp with NEAREST, and scaling one down is where
      # TRILINEAR's mipmaps earn their cost.
      def filter(texture, width, height)
        if width > texture.width || height > texture.height
          :nearest
        else
          :trilinear
        end
      end

      # Upstream's comment says this was translated from AdwAvatar's source,
      # and it is a fill rather than a fit: the shorter side is pinned to the
      # target and the longer one overshoots it. A portrait page is therefore
      # MAX_SIZE wide and taller than MAX_SIZE, which is what upstream shows.
      #
      # The scale factor is the widget's, so the snapshot is sized in device
      # pixels and a HiDPI display gets a sharp thumbnail rather than a
      # doubled one.
      def scaled_size(texture)
        (MAX_SIZE * image.scale_factor).to_f.then do |size|
          if texture.width > texture.height
            [texture.width * size / texture.height, size]
          elsif texture.height > texture.width
            [size, texture.height * size / texture.width]
          else
            [size, size]
          end
        end
      end
  end
end

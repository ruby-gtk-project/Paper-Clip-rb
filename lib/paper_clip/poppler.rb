# frozen_string_literal: true

require 'cairo'
require 'gobject-introspection'

# Poppler, loaded from its GObject-Introspection typelib.
#
# This file has no upstream counterpart: Vala reaches poppler-glib through
# `--pkg poppler-glib` and its bundled VAPI, and there is no Poppler gem in
# this port's bundle to do the same job. What there is, once `poppler` is
# built with `introspectionSupport = true` in flake.nix, is
# `Poppler-0.18.typelib` on `GI_TYPELIB_PATH` — and a bare
# `GObjectIntrospection::Loader` subclass is enough to turn that into real
# Ruby classes. FINDINGS.md §1 called this route "plumbing, not research";
# this is the plumbing.
#
# `require 'cairo'` comes first and is not incidental: `Poppler::Page#render`
# takes a `cairo_t`, and the argument converter that turns a
# `Cairo::Context` into one is registered by the cairo gem. Loading the
# typelib without it leaves `render` unusable.
#
# The loader names Ruby constants after the typelib's enum members, and
# `Poppler.Selection3D`, `PopplerPrintScaling` and the rotation values give
# it names like `3D`, `1` and `270` to try. Ruby's `rb_define_const` warns
# once per name and skips it — harmless, since nothing here uses them, but
# fifteen lines of noise on every launch. `$VERBOSE` is the only switch that
# silences `rb_warn`, so it is lowered for the duration of the load and put
# back afterwards.
module Poppler
  class Loader < GObjectIntrospection::Loader
    # Rasterising a page is the one call in this library worth doing on
    # another thread, which is the whole premise of upstream's Thumbnailer
    # (`src/Services/Thumbnailer.vala:57`). A Ruby thread that holds the GVL
    # across it would stall the main loop just the same, so these are marked
    # to release it: they are long, pure C and never call back into Ruby.
    UNLOCKED = %w[render render_for_printing render_for_printing_with_options].freeze

    # Public, because the loader reaches it through `respond_to?`.
    def should_unlock_gvl?(info, _target_module)
      UNLOCKED.include?(info.name)
    end
  end

  verbose = $VERBOSE
  $VERBOSE = nil
  begin
    Loader.load('Poppler', self)
  ensure
    $VERBOSE = verbose
  end

  # Poppler declares seven constructors for `Poppler::Document`, and the
  # loader folds all of them into one `initialize` that tries each in turn
  # and keeps whichever accepts the arguments. `new_from_data` accepts two
  # strings, so it wins the race against `new_from_file` for `(uri,
  # password)` — and then reports a perfectly good PDF as damaged, because it
  # read the URI as the file's bytes.
  #
  # Each constructor also gets a private `initialize_<name>` of its own,
  # which is the one worth calling: it names the signature instead of
  # guessing at it.
  def self.open(uri, password = nil)
    Document.allocate.tap { |document| document.send(:initialize_new_from_file, uri, password) }
  end
end

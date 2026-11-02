# frozen_string_literal: true

require 'adwaita'

require_relative 'document'

module PaperClip
  # DocumentManager owns the open document and knows whether it has unsaved
  # changes.
  #
  # Ported from upstream's src/Services/DocumentManager.vala. Assigning a
  # document clears the dirty flag and subscribes to the document's change
  # notifications; a successful save clears it again. Upstream has to
  # disconnect the previous document's signals by hand, which this port does
  # not: a Document owns its own observer list, so dropping the object drops
  # the subscription with it.
  #
  # One manager belongs to one window, and the quit path collects the managers
  # of every open window to decide what still needs saving.
  class DocumentManager
    attr_reader :document

    def initialize
      @document = nil
      @changed = false
    end

    def changed? = @changed

    def document=(value)
      @document = value
      @changed = false
      value&.on_change { @changed = true }
    end

    # `target_path` defaults to the file the document came from, which is what
    # the plain Save action wants; Save As passes the chosen path instead.
    def save(target_path = nil, on_done: nil, on_error: nil)
      @document.then do |doc|
        if doc
          doc.save_async(
            target_path || doc.path,
            on_done:  ->(_) { finish_save(on_done) },
            on_error: on_error,
          )
        end
      end
    end

    private

      def finish_save(on_done)
        @changed = false
        on_done&.call
      end
  end
end

# frozen_string_literal: true

require_relative 'document'

module PaperClip
  # DocumentManager owns the open document and knows whether it has unsaved
  # changes.
  #
  # Ported from upstream's src/Services/DocumentManager.vala. Assigning a
  # document clears the dirty flag and subscribes to the document's change
  # notifications; a successful save clears it again.
  #
  # Upstream disconnects the previous document's signals by hand. A Document
  # here owns its own observer list, so there is nothing to disconnect — but
  # the subscription outlives the assignment as long as something else still
  # holds the old document, and the save-changes dialog does exactly that.
  # Hence the identity check in mark_changed: a notification from a document
  # this manager no longer owns is not this manager's dirty flag.
  #
  # One manager belongs to one window, and the quit path collects the managers
  # of every open window to decide what still needs saving.
  #
  # No widget toolkit is required here: a manager is the dirty flag and the
  # save, and the spec suite exercises both without a display.
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
      value&.on_change { mark_changed(value) }
    end

    # `target_file` is a Gio::File and defaults to the file the document came
    # from, which is what the plain Save action wants; Save As passes the
    # chosen file instead.
    def save(target_file = nil, on_done: nil, on_error: nil)
      @document.then do |doc|
        if doc
          doc.save_async(
            target_file || doc.original_file,
            on_done:  ->(_) { finish_save(on_done) },
            on_error: on_error,
          )
        end
      end
    end

    private

      def mark_changed(source)
        if source.equal?(@document)
          @changed = true
        end
      end

      def finish_save(on_done)
        @changed = false
        on_done&.call
      end
  end
end

# frozen_string_literal: true

require 'glib2'

module PaperClip
  # ThreadManager runs expensive work off the main loop.
  #
  # Ported from upstream's src/ThreadManager.vala, which keeps a single-worker
  # GLib ThreadPool and resumes the calling coroutine from an idle callback
  # once the work is done. The shape here is the same — one worker, work
  # serialised through a queue, results delivered on the main loop — but the
  # continuation is an explicit callback rather than a yielded coroutine,
  # because Ruby has no `yield`/`callback` pair to hand a thread.
  #
  # Delivering through GLib::Idle matters: the callbacks touch widgets, and
  # GTK may only be touched from the thread running the main loop.
  #
  # glib2 and not adwaita: GLib::Idle is all this needs, and requiring the
  # widget toolkit here would make Document unloadable on a machine with no
  # display — which is where the spec suite runs.
  module ThreadManager
    QUEUE = Queue.new
    LOCK = Mutex.new

    # Hands `work` to the worker thread. `on_done` is called on the main loop
    # with whatever the block returned, `on_error` with the exception it
    # raised; exactly one of the two runs.
    def self.run_in_thread(on_done: nil, on_error: nil, &work)
      start
      QUEUE.push([work, on_done, on_error])
    end

    # The worker is started on first use, as upstream's init () is.
    def self.start
      LOCK.synchronize do
        @worker ||= Thread.new { worker_loop }
      end
    end

    def self.worker_loop
      loop { run_task(*QUEUE.pop) }
    end

    def self.run_task(work, on_done, on_error)
      deliver(on_done, work.call)
    rescue StandardError => e
      deliver(on_error, e)
    end

    def self.deliver(callback, value)
      if callback
        GLib::Idle.add do
          callback.call(value)
          false
        end
      end
    end

    private_class_method :worker_loop, :run_task, :deliver
  end
end

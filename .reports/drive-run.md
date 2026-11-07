# Drive run — Paper Clip

| | |
|---|---|
| Harness | `test/drive_paper_clip.rb` + `test/gtk_driver.rb` |
| Command | `nix develop --command xvfb-run -a ruby test/drive_paper_clip.rb` |
| Result | **318 of 318 checks passed — `DRIVE OK`**, re-run fresh for the round 8 audit (this count was 278, then 283, in earlier rounds; `60ffe4d` added the 35 checks that close the `Thumbnailer` error-domain and re-entrancy-guard gaps — see `.reports/component-parity.md` and `.reports/test-parity.md`) |
| Screenshots | 19 PNGs under `tmp/shots/`, all read back |
| Spec suite | `134 examples, 0 failures`, re-run fresh |

The harness builds the real application, opens the real windows and dialogs,
loads real PDFs off disk — including a genuinely AES-128-encrypted one — and
asserts the observable result of each interaction. It covers all 29 files
under `lib/paper_clip/`.

## Port bugs the run found

All three were invisible to `ruby -c`, to `require`, and to the spec suite,
and each broke a feature or an error path that had therefore never worked
for anyone, or never been proven to.

### 1. Drag and drop raised `NoMethodError` and took the process with it

`Window#on_file_dropped` treated the `drop` signal's argument as a
`Gio::File`. It is not. GtkDropTarget's C signature is

```c
gboolean drop (GtkDropTarget *self, const GValue *value, double x, double y)
```

and these bindings hand that `GValue` over as a `GLib::Value` rather than
unboxing it. Every drop therefore died in `pdf?` with

```
undefined method 'query_info' for an instance of GLib::Value
```

and, because the raise travelled back out through GTK's own signal emission,
it segfaulted the process. Dragging a PDF onto the window — the whole of
upstream's welcome page — could never have worked.

Fixed in `lib/paper_clip/window.rb` by unwrapping the value.

### 2. Closed windows were never forgotten

`Application#new_window` connected to the window's own `destroy` signal to
drop it from `@windows`. GtkWidget emits `destroy` from `dispose`, and
`dispose` only runs when the last reference goes — which it never does here,
because the port's `Window` holds its widget in an instance variable for the
lifetime of the object. A closed window stayed in the list forever, so
`query-quit` went on offering to save the document of a window the user had
already closed, and `Ctrl+Q` could reopen a save-changes dialog for a window
that was not on screen.

Fixed in `lib/paper_clip/application.rb` by listening for the application's
`window-removed` instead, which `gtk_window_destroy` fires on its way out
whatever the reference count is.

### 3. A failed thumbnail export did not raise `Thumbnailer::ExportError`

`Thumbnailer#export`'s `rescue Cairo::Error, SystemCallError` did not match
the exception `surface.write_to_png` actually raises on a real write
failure, `Cairo::WriteError` — which is a Ruby `IOError`, not a
`Cairo::Error`, under the cairo-ruby bindings. A write failure (missing
parent directory, full disk) would have propagated unrescued instead of
surfacing the port's own named error. Found by the round 8 drive step that
forces the write to fail for real, rather than by inspection.

Fixed in `lib/paper_clip/thumbnailer.rb` by also rescuing `IOError`.

## Binding gaps — not port bugs, and not worked around

### `g_application_open` cannot be called or emitted from Ruby

```
NotImplementedError: TODO: in Ruby -> GIArgument(array/C)[interface(interface)](GFile)
  gobject-introspection-4.3.9/lib/gobject-introspection/loader.rb:722
  Gio::Application#open
```

Emitting the `open` signal by hand instead segfaults in the same marshaller.
The inbound direction works: GTK's own emission, which is what a command-line
invocation and a desktop file-association produce, converts the `GFile` array
into Ruby correctly.

So the port's open path is sound, and the harness drives it the only way it
can be driven — a child process that runs the application with file arguments
and reports what it opened. Four checks cover one PDF, a refused non-PDF and
two PDFs at once.

### `adw_alert_dialog_response()` is not bound

`Adwaita::AlertDialog` exposes `add_response`, `get_response_appearance`,
`set_response_enabled` and the rest, but no plain `response`. The two halves
cannot be faked either: `adw_dialog_close()` on an alert dialog emits the
close response on its way out, so emitting `save` and then closing fires
`cancel` straight afterwards — and the port's state machine correctly reads
that as "never mind", leaving the window it was told to close open.

The harness therefore answers the dialog the way a user does: it finds the
`GtkButton` AdwAlertDialog built for that response, by the response's own
label, and clicks it. That emits exactly one response and closes the dialog.

### `g_action_group_list_actions` is not bound

`Gio::SimpleActionGroup` has `has_action?`, `lookup_action` and
`query_action`, but no `list_actions`. The editor's deliberately-empty action
group is therefore asserted by what emptiness means here: it shadows none of
the window actions its own shortcuts point at, so `Ctrl+S` reaches
`win.save`.

### `g_application_query_action` asserts registration

`has_action?` is a `GActionGroup` call and aborts with

```
GLib-GIO-CRITICAL: g_application_query_action: assertion 'is_registered' failed
```

on an application that has never run. The step that checks a fresh
application's actions uses `lookup_action`, the `GActionMap` call, which works
before registration.

## What the harness does not cover, and why

`Gtk::FileDialog` is asynchronous and raises on cancel, so the `win.open` and
`win.save-as` choosers cannot be clicked through. What is driven instead is
every branch around them: `win.open` with unsaved work (which raises the
save-changes dialog rather than a chooser), and the save the `save-as`
callback performs once a path has been chosen.

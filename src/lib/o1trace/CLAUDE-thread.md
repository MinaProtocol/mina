# O1trace.Thread (and background_thread)

## What it solves

Named threads with fiber tracking for observability (O1trace plugins).
`O1trace.thread name f` runs `f` inside `Scheduler.within_context`, attaching
a `Thread.Fiber` to the execution context. If `f` raises synchronously, the
exception is converted to `failwithf` with the thread name.

`O1trace.background_thread name f` is `don't_wait_for (thread name f)` —
schedules `f` as a background task, returning immediately.

## Key semantics

### `thread name f`

1. Creates or reuses a `Thread.Fiber` for `name`.
2. Attaches it to the current `Scheduler.current_execution_context()`.
3. Runs `f` inside `Scheduler.within_context`.
4. If `Scheduler.within_context` returns `Error ()` (the scheduler was
   shut down), calls `failwithf "timing task \`%s\` failed, exception
   reported to parent monitor" name`.
5. Returns the result of `f` (which is typically a `Deferred.t`).

### `background_thread name f`

Same as `don't_wait_for (thread name f)`. The returned deferred is ignored.
If the deferred eventually raises, the error goes to Async's current monitor
(same as any `don't_wait_for`).

### Recursive thread detection

If `f` calls `thread` with the same `name` while already inside a fiber of
that name, the existing fiber is reused (avoids duplicate fiber registration).

## Common pitfalls

1. **`background_thread` + deferred exception**: since the deferred is
   `don't_wait_for`-ed, any async exception propagates to the current
   monitor. This is the standard Async pattern — the same as any
   `don't_wait_for (main_loop t)`.
2. **`failwithf` on scheduler shutdown**: during daemon shutdown,
   `Scheduler.within_context` may return `Error ()`, causing a `failwithf`.
   This is expected during normal shutdown and should not be treated as
   a crash.
3. **Not an error boundary**: `thread` does NOT set up a `Monitor.try_with`.
   Exceptions from `f` (synchronous) are caught by `failwithf`; async
   exceptions from the returned deferred propagate to the parent monitor.

## Source files

- `src/lib/o1trace/o1trace.ml` (lines 58-100)

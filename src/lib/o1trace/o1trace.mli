val trace_event : string -> unit
(** Emit an instantaneous named event.

  These show up as little vertical bars underneath the horizontal bars measuring tasks.
*)

val trace_recurring_task : string -> (unit -> 'a) -> 'a
(** Trace a task that happens more than once.

  This is just like [trace_task], it just prepends "R&" to the name,
  which trace-tool knows how to merge. Otherwise, each task gets its
  own row in the trace viewer.
 *)

val trace_task : string -> (unit -> 'a) -> 'a
(** Trace a task that happens once.

  [trace_task name f] makes a new [Async.Execution_context.t] with a new
  "task id", gives it [name] to show in the trace-viewer. Any deferreds
  created by [f] will inherit this task id. When the async scheduler starts
  executing a task, it logs the task id to the trace file. These show up in
  the trace-viewer as their own row, with [name] as the label.
*)

val measure : string -> (unit -> 'a) -> 'a
(** Measure how long a function call takes.

  This will not show up as its own row in the trace-viewer, but rather as
  stacked rectangles showing the stack of things that are measured. *)

val start_tracing : Async.Writer.t -> unit
(** Enable tracing, using the supplied writer.

  Tracing is global, so don't call this more than once in the same process
  and expect multiple trace files!
*)

val stop_tracing : unit -> unit
(** Stop tracing and forget about the writer supplied to [start_tracing]. *)

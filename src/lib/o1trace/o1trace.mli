(** Emit an instantaneous named event.

  These show up as little vertical bars underneath the horizontal bars measuring tasks.
*)
val trace_event : string -> unit

(** Trace some deferred work.

  [trace name f] makes a new [Async.Execution_context.t] with a new
  "task id", gives it [name] to show in the trace-viewer. Any deferreds
  created by [f] will inherit this task id. When the async scheduler starts
  executing a task, it logs the task id to the trace file. These show up in
  the trace-viewer as their own row, with [name] as the label.
*)
val trace : string -> (unit -> 'a) -> 'a

(** Trace some deferred work that happens more than once.

  [trace_recurring name f] is the same as [trace ("R&" ^ name) f]. The prefix
  collapses all the traces into a single row.
 *)
val trace_recurring : string -> (unit -> 'a) -> 'a

(** Trace the execution of some background loop.

  [trace_task name f] is the same as [don't_wait_for (trace name f)].

  *)
val trace_task : string -> (unit -> unit Async.Deferred.t) -> unit

(** Trace the execution of some background loop that happens more than once.

  [trace_recurring_task name f] is the same as [trace_task ("R&" ^ name) f].
 *)
val trace_recurring_task : string -> (unit -> unit Async.Deferred.t) -> unit

(** Measure how long a function call takes.

  This will not show up as its own row in the trace-viewer, but rather as
  stacked rectangles showing the stack of things that are measured. *)
val measure : string -> (unit -> 'a) -> 'a

(** Enable tracing, using the supplied writer.

  Tracing is global, so don't call this more than once in the same process
  and expect multiple trace files!
*)
val start_tracing : Async.Writer.t -> unit

(** Stop tracing and forget about the writer supplied to [start_tracing]. *)
val stop_tracing : unit -> unit

(** Forget about the current tid and execute [f] with tid=0.

This is useful, for example, when opening a writer. The writer will
internally do a lot of work that will show up in the trace when it
isn't necessarily desired.
*)
val forget_tid : (unit -> 'a) -> 'a

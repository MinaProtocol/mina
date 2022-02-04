open Core_kernel
open Async_kernel

include module type of Intf

module Thread_registry : sig
  val assign_tid : string -> Execution_context.t -> Execution_context.t

  val get_thread_name : int -> string option

  val iter_threads : f:(string -> int -> unit) -> unit
end

module Thread_timers : sig
  val get_elapsed_time : string -> Time.Span.t

  val iter_timed_threads : f:(string -> unit) -> unit
end

module No_trace : S_with_hooks

include S

(** Forget about the current tid and execute [f] with tid=0.

    This is useful, for example, when opening a writer. The writer will
    internally do a lot of work that will show up in the trace when it
    isn't necessarily desired.
*)
val forget_tid : (unit -> 'a) -> 'a

val time_execution : string -> (unit -> 'a) -> 'a

(** Swap the tracing implementation for the one provided in the given module. *)
val set_implementation : (module S_with_hooks) -> unit

open Core_kernel

include module type of Intf

module Thread : sig
  val iter_threads : f:(string -> unit) -> unit

  val get_elapsed_time : string -> Time_ns.Span.t option
end

module No_trace : S_with_hooks

include S

(** Forget about the current tid and execute [f] with tid=0.

    This is useful, for example, when opening a writer. The writer will
    internally do a lot of work that will show up in the trace when it
    isn't necessarily desired.
*)
val forget_tid : (unit -> 'a) -> 'a

val time_execution' : string -> (unit -> 'a) -> 'a

val time_execution : string -> (unit -> 'a) -> 'a

(** Swap the tracing implementation for the one provided in the given module. *)
val set_implementation : (module S_with_hooks) -> unit

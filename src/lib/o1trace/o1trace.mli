module type S = Intf.S

module No_trace : S

(** Swap the tracing implementation for the one provided in the given module. *)
val set_implementation : (module S) -> unit

include S

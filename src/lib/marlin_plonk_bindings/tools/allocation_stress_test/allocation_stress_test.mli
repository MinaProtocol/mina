module type S = sig
  type t

  val name : string

  val exercise : unit -> unit -> t
end

val exercises : (module S) list Core_kernel.ref

val register_one : (module S) -> unit

val register : (module S) list -> unit

val run_simple_exercise : Core_kernel.String.t -> int -> unit

val get_names : unit -> string list

val run : unit -> unit

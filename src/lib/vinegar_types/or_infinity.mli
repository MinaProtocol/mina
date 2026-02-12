(* Representation for values that may be infinite *)

(** [t] is the type of possibly infinite values *)
type 'a t = Infinity | Finite of 'a

val finite_exn : 'a t -> 'a

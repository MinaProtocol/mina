(* Representation for values that may be infinite *)

(** type of possibly infinite values *)
type 'a t = Infinity | Finite of 'a

(** [finite_exn v] *)
val finite_exn : 'a t -> 'a

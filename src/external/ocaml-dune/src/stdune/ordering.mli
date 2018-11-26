(** Element ordering *)

type t =
  | Lt (** Lesser than  *)
  | Eq (** Equal        *)
  | Gt (** Greater than *)

val of_int : int -> t
val to_int : t -> int

(** returns the string representation. one of: "<", "=", ">" *)
val to_string : t -> string

val neq : t -> bool

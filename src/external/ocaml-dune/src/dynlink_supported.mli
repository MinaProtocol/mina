(** Track whether dynamic loading of code is supported *)

module By_the_os : sig
  type t
  val of_bool : bool -> t
  val get : t -> bool
end

type t
val of_bool : bool -> t
val get : t -> By_the_os.t -> bool

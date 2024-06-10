(* Implementing triplets *)

module Label : sig
  type t = A | B | C [@@deriving equal]

  (** [all] returns the set of all elements of type {!t} as a list. *)
  val all : t list
end

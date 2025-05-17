(* NOTE:
   This module implemented type safe heterogeneous hash table.
   One unsafe `Obj.magic` is used, GADT is here to guarantee type safety, as long
   as the underlying yojsonable implementation is injective.
*)

module Make (Key : sig
  type _ t

  val compare : _ t -> _ t -> int

  val hash : _ t -> int

  val sexp_of_t : _ t -> Sexp.t
end) : sig
  type table

  val create : unit -> table

  val find : table -> 'a Key.t -> 'a option

  val set : table -> key:'a Key.t -> data:'a -> unit
end

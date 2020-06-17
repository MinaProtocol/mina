module type Type_with_delete = sig
  type t

  val delete : t -> unit
end

module type Vector = sig
  type elt

  include Type_with_delete

  val create : unit -> t

  val emplace_back : t -> elt -> unit

  val length : t -> int

  val get : t -> int -> elt
end

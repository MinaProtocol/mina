module type S = sig
  type hash

  type elem = [ `Left of hash | `Right of hash ] [@@deriving sexp, equal]

  val elem_hash : elem -> hash

  type t = elem list [@@deriving sexp, equal]

  val implied_root : t -> hash -> hash
end

module Make (Hash : sig
  type t [@@deriving sexp, equal]

  val merge : height:int -> t -> t -> t

  val equal : t -> t -> bool
end) : S with type hash := Hash.t

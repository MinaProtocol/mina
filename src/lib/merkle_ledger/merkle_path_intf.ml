module type S = sig
  type hash

  type elem = [`Left of hash | `Right of hash] [@@deriving sexp]

  val elem_hash : elem -> hash

  type t = elem list [@@deriving sexp]

  val implied_root : t -> hash -> hash
end

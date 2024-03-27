module type S = sig
  type hash

  type elem = [ `Left of hash | `Right of hash ] [@@deriving sexp, equal]

  val elem_hash : elem -> hash

  type t = elem list [@@deriving sexp, equal]

  val implied_root : t -> hash -> hash

  (** [check_path path leaf_hash root_hash] is used in tests to check that 
      [leaf_hash] along with [path] actually corresponds to [root_hash]. *)
  val check_path : t -> hash -> hash -> bool
end

module Make (Hash : sig
  type t [@@deriving sexp, equal]

  val merge : height:int -> t -> t -> t

  val equal : t -> t -> bool
end) : S with type hash := Hash.t

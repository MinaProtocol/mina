open Core

type ('hash, 'key, 'account) t [@@deriving bin_io, sexp]

type index = int

module type S = sig
  type hash

  type key

  type account

  type nonrec t = (hash, key, account) t [@@deriving bin_io, sexp]

  val of_hash : depth:int -> hash -> t

  val get_exn : t -> index -> account

  val path_exn : t -> index -> [`Left of hash | `Right of hash] list

  val set_exn : t -> index -> account -> t

  val find_index_exn : t -> key -> index

  val add_path :
    t -> [`Left of hash | `Right of hash] list -> key -> account -> t

  val merkle_root : t -> hash
end

module Make (Hash : sig
  type t [@@deriving bin_io, eq, sexp]

  val merge : height:int -> t -> t -> t
end) (Key : sig
  type t [@@deriving bin_io, eq, sexp]
end) (Account : sig
  type t [@@deriving bin_io, eq, sexp]

  val hash : t -> Hash.t
end) :
  S
  with type hash := Hash.t
   and type key := Key.t
   and type account := Account.t

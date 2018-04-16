open Core

module type S =
  functor (Hash : sig 
       type hash [@@deriving sexp, hash, compare, bin_io]
       type account [@@deriving sexp, bin_io]
       val hash_account : account -> hash 
       val empty_hash : hash
       val merge : hash -> hash -> hash
     end)
    (Max_depth : sig val max_depth : int end)
    (Key : sig 
        type t [@@deriving sexp, bin_io]
        include Hashable.S_binable with type t := t
     end) -> sig

  type index = int

  type t
  [@@deriving sexp, hash, compare, bin_io]

  val copy : t -> t

  module Path : sig
    type elem =
      [ `Left of Hash.hash
      | `Right of Hash.hash
      ]
    [@@deriving sexp]

    val elem_hash : elem -> Hash.hash

    type t = elem list
    [@@deriving sexp]

    val implied_root : t -> Hash.hash -> Hash.hash
  end

  val create : depth:int -> t

  val depth : t -> int

  val length : t -> int

  val get
    : t
    -> Key.t
    -> Hash.account option

  val update
    : t
    -> Key.t
    -> Hash.account
    -> unit

  val merkle_root
    : t
    -> Hash.hash

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
  val hash_fold_t : Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state
  val compare : t -> t -> int

  val merkle_path
    : t
    -> Key.t
    -> Path.t option

  val key_of_index
    : t -> index -> Key.t option

  val index_of_key
    : t -> Key.t -> index option

  val key_of_index_exn
    : t -> index -> Key.t

  val index_of_key_exn
    : t -> Key.t -> index

  val get_at_index
    : t -> index -> [ `Ok of Hash.account | `Index_not_found ]

  val update_at_index
    : t -> index -> Hash.account -> [ `Ok | `Index_not_found ]

  val merkle_path_at_index
    : t -> index -> [ `Ok of Path.t | `Index_not_found ]

  val get_at_index_exn
    : t -> index -> Hash.account

  val update_at_index_exn
    : t -> index -> Hash.account -> unit

  val merkle_path_at_index_exn
    : t -> index -> Path.t
end

module Make : S

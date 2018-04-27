open Core

module type S = sig
  type hash
  type account
  type key

  val depth : int

  type index = int

  type t
  [@@deriving sexp, bin_io]

  include Container.S0 with type t := t
                        and type elt := account

  val copy : t -> t

  module Path : sig
    type elem =
      [ `Left of hash
      | `Right of hash
      ]
    [@@deriving sexp]

    val elem_hash : elem -> hash

    type t = elem list
    [@@deriving sexp]

    val implied_root : t -> hash -> hash
  end

  val create : unit -> t

  val length : t -> int

  val get : t -> key -> account option

  val update : t -> key -> account -> unit

  val merkle_root : t -> hash

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value
  val hash_fold_t : Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state
  val compare : t -> t -> int

  val merkle_path
    : t -> key -> Path.t option

  val key_of_index
    : t -> index -> key option

  val index_of_key
    : t -> key -> index option

  val key_of_index_exn
    : t -> index -> key

  val index_of_key_exn
    : t -> key -> index

  val get_at_index
    : t -> index -> [ `Ok of account | `Index_not_found ]

  val update_at_index
    : t -> index -> account -> [ `Ok | `Index_not_found ]

  val merkle_path_at_index
    : t -> index -> [ `Ok of Path.t | `Index_not_found ]

  val get_at_index_exn
    : t -> index -> account

  val update_at_index_exn
    : t -> index -> account -> unit

  val merkle_path_at_index_exn
    : t -> index -> Path.t
end

module type F =
  functor (Hash : sig 
       type hash [@@deriving sexp, hash, compare, bin_io]
       module Account : sig
         type t [@@deriving sexp, eq, bin_io]
       end
       val hash_account : Account.t -> hash 
       val empty_hash : hash
       val merge : hash -> hash -> hash
     end)
    (Key : sig 
        type t [@@deriving sexp, bin_io]
        include Hashable.S_binable with type t := t
     end)
    (Depth : sig val depth : int end)
    -> S with type hash := Hash.hash
          and type account := Hash.Account.t
          and type key := Key.t

module Make : F

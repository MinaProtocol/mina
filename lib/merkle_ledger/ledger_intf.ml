open Core

module type S = sig
  type hash

  type account

  type key

  val depth : int

  type index = int

  type t [@@deriving sexp, bin_io]

  include Container.S0 with type t := t and type elt := account

  val copy : t -> t

  module Path : Merkle_path.S with type hash := hash

  type path = Path.t

  module Addr : Merkle_address.S

  val create : unit -> t

  val length : t -> int

  val get : t -> key -> account option

  val set : t -> key -> account -> unit

  val update : t -> key -> f:(account option -> account) -> unit

  val merkle_root : t -> hash

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val compare : t -> t -> int

  val merkle_path : t -> key -> path option

  val key_of_index : t -> index -> key option

  val index_of_key : t -> key -> index option

  val key_of_index_exn : t -> index -> key

  val index_of_key_exn : t -> key -> index

  val get_at_index : t -> index -> [`Ok of account | `Index_not_found]

  val set_at_index : t -> index -> account -> [`Ok | `Index_not_found]

  val merkle_path_at_index : t -> index -> [`Ok of path | `Index_not_found]

  val get_at_index_exn : t -> index -> account

  val set_at_index_exn : t -> index -> account -> unit

  val merkle_path_at_addr_exn : t -> Addr.t -> path

  val merkle_path_at_index_exn : t -> index -> path

  val set_at_addr_exn : t -> Addr.t -> account -> unit

  val get_inner_hash_at_addr_exn : t -> Addr.t -> hash

  val set_inner_hash_at_addr_exn : t -> Addr.t -> hash -> unit

  val extend_with_empty_to_fit : t -> int -> unit

  val set_all_accounts_rooted_at_exn : t -> Addr.t -> account list -> unit

  val get_all_accounts_rooted_at_exn : t -> Addr.t -> account list

  val recompute_tree : t -> unit
end

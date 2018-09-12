open Core

module type S = sig
  type hash

  type account

  type key

  type index = int

  type t [@@deriving sexp, bin_io]

  val copy : t -> t

  module Path : Merkle_path.S with type hash := hash

  module Addr : Merkle_address.S

  val create : unit -> t

  val get : t -> key -> account option

  val set : t -> key -> account -> unit

  val update : t -> key -> f:(account option -> account) -> unit

  val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

  val hash_fold_t :
    Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

  val compare : t -> t -> int

  val merkle_path : t -> key -> Path.t option

  val key_of_index : t -> index -> key option

  val index_of_key : t -> key -> index option

  val key_of_index_exn : t -> index -> key

  val index_of_key_exn : t -> key -> index

  val get_at_index : t -> index -> [`Ok of account | `Index_not_found]

  val set_at_index : t -> index -> account -> [`Ok | `Index_not_found]

  val merkle_path_at_index : t -> index -> [`Ok of Path.t | `Index_not_found]

  val get_at_index_exn : t -> index -> account

  val set_at_index_exn : t -> index -> account -> unit

  val merkle_path_at_index_exn : t -> index -> Path.t

  val set_at_addr_exn : t -> Addr.t -> account -> unit

  val extend_with_empty_to_fit : t -> int -> unit

  include Syncable_intf.S
          with type root_hash := hash
           and type hash := hash
           and type account := account
           and type addr := Addr.t
           and type t := t
           and type path := Path.t

  val recompute_tree : t -> unit
end

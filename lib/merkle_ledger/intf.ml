open Core

module type Key = sig
  type t [@@deriving sexp, bin_io]

  val empty : t

  include Hashable.S_binable with type t := t
end

module type Balance = sig
  type t [@@deriving eq]

  val zero : t
end

module type Account = sig
  type t [@@deriving bin_io, eq]

  type key

  val public_key : t -> key
end

module type Hash = sig
  type t [@@deriving bin_io, sexp]

  type account

  val empty : t

  val merge : height:int -> t -> t -> t

  val hash_account : account -> t
end

module type Depth = sig
  val depth : int
end

module type Key_value_database = sig
  type t

  val copy : t -> t

  val create : directory:string -> t

  val destroy : t -> unit

  val get : t -> key:Bigstring.t -> Bigstring.t option

  val set : t -> key:Bigstring.t -> data:Bigstring.t -> unit

  val delete : t -> key:Bigstring.t -> unit
end

module type Stack_database = sig
  type t

  val copy : t -> t

  val create : filename:string -> t

  val destroy : t -> unit

  val push : t -> Bigstring.t -> unit

  val pop : t -> Bigstring.t option

  val length : t -> int
end

module type Ledger_S = sig
  type hash

  type account

  type key

  val depth : int

  type index = int

  type t [@@deriving sexp, bin_io]

  module Path : Merkle_path.S with type hash := hash

  type path = Path.t

  include Container.S0 with type t := t and type elt := account

  val copy : t -> t

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

  val get_at_addr_exn : t -> Addr.t -> account

  val set_at_addr_exn : t -> Addr.t -> account -> unit

  val get_inner_hash_at_addr_exn : t -> Addr.t -> hash

  val set_inner_hash_at_addr_exn : t -> Addr.t -> hash -> unit

  val extend_with_empty_to_fit : t -> int -> unit

  val set_all_accounts_rooted_at_exn : t -> Addr.t -> account list -> unit

  val get_all_accounts_rooted_at_exn : t -> Addr.t -> account list

  val recompute_tree : t -> unit

  val empty_hash_array : hash array

  val get_leaf_hash : t -> index -> hash

  val to_index : Addr.t -> index
end

module type Database_S = sig
  type account

  type hash

  type key

  type t

  type error = Account_key_not_found | Out_of_leaves | Malformed_database [@@deriving sexp]

  module Addr : Merkle_address.S

  module Path : Merkle_path.S with type hash := hash
  
  type path = Path.t

  val copy : t -> t

  val max_depth : int

  val create : key_value_db_dir:string -> stack_db_file:string -> t

  val destroy : t -> unit

  val num_accounts : t -> int

  val get_account : t -> key -> account option

  val set_account : t -> account -> (unit, error) Result.t

  val merkle_root : t -> hash

  val merkle_path : t -> key -> path

  val merkle_path_at_addr : t -> Addr.t -> path

  val set_inner_hash_at_addr_exn : t -> Addr.t -> hash -> unit

  val get_inner_hash_at_addr_exn : t -> Addr.t -> hash

  val get_all_accounts_rooted_at_exn : t -> Addr.t -> account list

  val set_all_accounts_rooted_at_exn : t -> Addr.t -> account list -> unit

  val empty_hash_array : hash array
end

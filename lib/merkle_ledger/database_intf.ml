open Core

module type S = sig
  type account

  type hash

  type key

  type t

  type error = Account_key_not_found | Out_of_leaves | Malformed_database

  module Addr : Merkle_address.S

  module MerklePath : sig
    type t = Direction.t * hash

    val implied_root : t list -> hash -> hash
  end

  val create : key_value_db_dir:string -> stack_db_file:string -> t

  val destroy : t -> unit

  val num_accounts : t -> int

  val get_key_of_account : t -> account -> (key, error) Result.t

  val get_account : t -> key -> account option

  val set_account : t -> account -> (unit, error) Result.t

  val merkle_root : t -> hash

  val merkle_path : t -> key -> MerklePath.t list

  val merkle_path_at_addr : t -> Addr.t -> MerklePath.t list

  val set_inner_hash_at_addr_exn : t -> Addr.t -> hash -> unit

  val get_inner_hash_at_addr_exn : t -> Addr.t -> hash

  val get_accounts_starting_with_exn : t -> Addr.t -> account list

  val set_accounts_starting_with_exn : t -> Addr.t -> account list -> unit
end

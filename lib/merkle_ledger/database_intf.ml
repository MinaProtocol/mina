open Core

module type S = sig
  type account

  type hash

  type key

  type t

  type error = Account_key_not_found | Out_of_leaves | Malformed_database
  [@@deriving sexp]

  module Addr : Merkle_address.S

  module Path : Merkle_path.S with type hash := hash

  type path = Path.t

  val copy : t -> t

  val create : key_value_db_dir:string -> stack_db_file:string -> t

  val destroy : t -> unit

  val length : t -> int

  val get_key_of_account : t -> account -> (key, error) Result.t

  val get : t -> key -> account option

  val set : t -> account -> (unit, error) Result.t

  val merkle_root : t -> hash

  val merkle_path : t -> key -> path

  val merkle_path_at_addr : t -> Addr.t -> path

  val set_inner_hash_at_addr_exn : t -> Addr.t -> hash -> unit

  val get_inner_hash_at_addr_exn : t -> Addr.t -> hash

  val get_all_accounts_rooted_at_exn : t -> Addr.t -> account list

  val set_all_accounts_rooted_at_exn : t -> Addr.t -> account list -> unit
end

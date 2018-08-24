open Core

module type Balance = sig
  type t [@@deriving eq]

  val zero : t
end

module type Account = sig
  type t [@@deriving bin_io, eq]

  type balance

  val empty : t

  val balance : t -> balance

  val set_balance : t -> balance -> t

  val public_key : t -> string
end

module type Hash = sig
  type t [@@deriving bin_io, eq]

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

  val create : directory:string -> t

  val destroy : t -> unit

  val get : t -> key:Bigstring.t -> Bigstring.t option

  val set : t -> key:Bigstring.t -> data:Bigstring.t -> unit

  val delete : t -> key:Bigstring.t -> unit
end

module type Stack_database = sig
  type t

  val create : filename:string -> t

  val destroy : t -> unit

  val push : t -> Bigstring.t -> unit

  val pop : t -> Bigstring.t option

  val length : t -> int
end

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

  val get_all_accounts_rooted_at_exn : t -> Addr.t -> account list

  val set_all_accounts_rooted_at_exn : t -> Addr.t -> account list -> unit
end

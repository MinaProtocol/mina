open Core

module type Balance_intf = sig
  type t [@@deriving eq]

  val zero : t
end

module type Account_intf = sig
  type t [@@deriving bin_io, eq]

  type balance

  val empty : t

  val balance : t -> balance

  val set_balance : t -> balance -> t

  val public_key : t -> string

  val gen : t Quickcheck.Generator.t
end

module type Hash_intf = sig
  type t [@@deriving bin_io, eq]

  type account

  val empty : t

  val merge : height:int -> t -> t -> t

  val hash_account : account -> t
end

module type Depth_intf = sig
  val depth : int
end

module type Key_value_database_intf = sig
  type t

  val create : directory:string -> t

  val destroy : t -> unit

  val get : t -> key:Bigstring.t -> Bigstring.t option

  val set : t -> key:Bigstring.t -> data:Bigstring.t -> unit

  val delete : t -> key:Bigstring.t -> unit
end

module type Stack_database_intf = sig
  type t

  val create : filename:string -> t

  val destroy : t -> unit

  val push : t -> Bigstring.t -> unit

  val pop : t -> Bigstring.t option
end

module type S = sig
  type account

  type hash

  type key

  type t

  type error = Account_key_not_found | Out_of_leaves | Malformed_database

  type address

  module MerklePath : sig
    type t = Direction.t * hash

    val implied_root : t list -> hash -> hash
  end

  val create : key_value_db_dir:string -> stack_db_file:string -> t

  val destroy : t -> unit

  val get_key_of_account : t -> account -> (key, error) Result.t

  val get_account : t -> key -> account option

  val set_account : t -> account -> (unit, error) Result.t

  val merkle_root : t -> hash

  val merkle_path : t -> key -> MerklePath.t list

  val set_inner_hash_at_addr_exn : t -> address -> hash -> unit

  val get_inner_hash_at_addr_exn : t -> address -> hash

  val get_all_accounts_rooted_at_exn : t -> address -> account list

  val set_all_accounts_rooted_at_exn : t -> address -> account list -> unit
end

module Make
    (Balance : Balance_intf)
    (Account : Account_intf with type balance := Balance.t)
    (Hash : Hash_intf with type account := Account.t)
    (Depth : Depth_intf)
    (Kvdb : Key_value_database_intf)
    (Sdb : Stack_database_intf) :
  S with type account := Account.t and type hash := Hash.t

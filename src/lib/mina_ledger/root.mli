open Mina_base

module type Stable_db_intf =
  Merkle_ledger.Intf.Ledger.DATABASE
    with type account := Account.t
     and type key := Signature_lib.Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type hash := Ledger_hash.t
     and type root_hash := Ledger_hash.t

module type Unstable_db_intf =
  Merkle_ledger.Intf.Ledger.DATABASE
    with type account := Account.Unstable.t
     and type key := Signature_lib.Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type hash := Ledger_hash.t
     and type root_hash := Ledger_hash.t

module type Any_ledger_intf =
  Merkle_ledger.Intf.Ledger.ANY
    with type account := Account.t
     and type key := Signature_lib.Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type hash := Ledger_hash.t

module type Converting_ledger_intf =
  Merkle_ledger.Intf.Ledger.Converting.WITH_DATABASE
    with type root_hash := Ledger_hash.t
     and type hash := Ledger_hash.t
     and type account := Account.t
     and type key := Signature_lib.Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type converted_account := Account.Unstable.t

(** Make a root ledger. A root ledger is a database-backed, unmasked ledger used
    at the root of a mina ledger mask tree. Currently only a single stable
    database is supported; an option will be added in future to create root
    ledgers backed by a converting merkle tree backed by a pair of stable
    account and unstable account databases.
*)
module Make
    (Any_ledger : Any_ledger_intf)
    (Stable_db : Stable_db_intf
                   with module Location = Any_ledger.M.Location
                    and module Addr = Any_ledger.M.Addr)
    (Unstable_db : Unstable_db_intf
                     with module Location = Any_ledger.M.Location
                      and module Addr = Any_ledger.M.Addr)
    (Converting_ledger : Converting_ledger_intf
                           with module Location = Any_ledger.M.Location
                            and module Addr = Any_ledger.M.Addr
                           with type primary_ledger = Stable_db.t
                            and type converting_ledger = Unstable_db.t) : sig
  type t

  type root_hash = Ledger_hash.t

  type hash = Ledger_hash.t

  type account = Account.t

  type addr = Stable_db.Addr.t

  type path = Stable_db.path

  module Config : sig
    type t [@@deriving yojson]

    (** The kind of database that should be used for this root. Only a single
        database of [Account.Stable.Latest.t] accounts is supported. A future
        update will add a converting merkle tree backing. *)
    type backing_type = Stable_db | Converting_db

    (** Create a root ledger configuration with the given backing type, using
        the [directory_name] as a template for its location *)
    val with_directory : backing_type:backing_type -> directory_name:string -> t

    (** Test if a root ledger backing already exists with this config *)
    val exists_backing : t -> bool

    (** Delete a backing of any type that might exist with this config, if 
        present. this function will try any backing type even if it didn't match
        up with one provided in the config *)
    val delete_any_backing : t -> unit

    (** Delete backing of a specific config *)
    val delete_backing : t -> unit

    (** Move the root backing at [src] to [dst]. Assumptions: the [src] and
        [dst] configs must have the same configured backing, there must be a
        root backing of the appropriate type at [src], there must not be a root
        backing at [dst], and there must be no database connections open for
        [src]. *)
    val move_backing_exn : src:t -> dst:t -> unit
  end

  (** Close the root ledger instance *)
  val close : t -> unit

  (** Retrieve the hash of the merkle root of the root ledger *)
  val merkle_root : t -> root_hash

  (** Create a root ledger backed by a single database in the given
      directory. *)
  val create : logger:Logger.t -> config:Config.t -> depth:int -> unit -> t

  val create_temporary :
       logger:Logger.t
    -> backing_type:Config.backing_type
    -> depth:int
    -> unit
    -> t

  (** Make a checkpoint of the root ledger and return a new root ledger backed
      by that checkpoint *)
  val create_checkpoint : t -> config:Config.t -> unit -> t

  (** Make a checkpoint of the root ledger *)
  val make_checkpoint : t -> config:Config.t -> unit

  (** View the root ledger as an unmasked [Any_ledger] so it can be used by code
      that does not need to know how the root is implemented *)
  val as_unmasked : t -> Any_ledger.witness

  (** Retrieve the depth of the root ledger *)
  val depth : t -> int

  (** Retrieve the number of accounts in the root ledger *)
  val num_accounts : t -> int

  (** Calculate the address path from [addr] to the merkle root. *)
  val merkle_path_at_addr_exn : t -> addr -> path

  (** Get the hash at the given [addr] in the ledger. Throws an exception if the
      [addr] doesn't point to a hash. *)
  val get_inner_hash_at_addr_exn : t -> addr -> hash

  (** Set the accounts at the leaves underneath [addr] in the ledger to the
      accounts in the given list. Throws an exception if the [addr] is not in
      the ledger, or if there are not exactly enough accounts in the list to set
      the values at the leaves. *)
  val set_all_accounts_rooted_at_exn : t -> addr -> account list -> unit

  (** For each addr-account pair, replace the account in the root with the given
      account. This is done as a single batch write. *)
  val set_batch_accounts : t -> (addr * account) list -> unit

  (** Get all of the accounts that are in a subtree of the underlying Merkle
    tree rooted at `address`. The accounts are ordered by their addresses. *)
  val get_all_accounts_rooted_at_exn : t -> addr -> (addr * account) list
end

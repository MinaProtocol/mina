open Mina_base

module Config : sig
  type t [@@deriving yojson]

  (** The kind of database backing that should be used for this root. *)
  type backing_type =
    | Stable_db
    | Converting_db of Mina_numbers.Global_slot_since_genesis.t

  (** Create a root ledger configuration with the given backing type, using
      the [directory_name] as a template for its location *)
  val with_directory : backing_type:backing_type -> directory_name:string -> t

  (** Test if a root ledger backing already exists with this config *)
  val exists_backing : t -> bool

  (** Test if a root ledger backing already exists with this config, ignoring
      the specific backing type of the root *)
  val exists_any_backing : t -> bool

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

(** The interface for an abstract root ledger. Root ledgers are used to
    represent the root snarked ledger and the epoch ledger snapshots, and so
    they are the base of the ledger mask tree that is maintained by the daemon
    as it participates in network consensus.

    This interface only contains root ledger methods that can transform existing
    root ledgers, or create new root ledgers from existing ones. Specific root
    ledger implementations will implement the [Intf_concrete] interface; once
    specific root ledgers are created, they can be cast to an [Any_root.witness]
    and passed to code that does not need to know the specific implementation of
    the root.
*)
type t

type root_hash = Ledger_hash.t

type hash = Ledger_hash.t

type account = Account.t

type addr = Ledger.Db.Addr.t

type path = Ledger.Db.path

(** Close the root ledger instance *)
val close : t -> unit

(** Create a root ledger backed by a single database in the given
      directory. *)
val create :
     logger:Logger.t
  -> config:Config.t
  -> depth:int
  -> ?assert_synced:bool
  -> unit
  -> t

val create_temporary :
  logger:Logger.t -> backing_type:Config.backing_type -> depth:int -> unit -> t

(** Retrieve the hash of the merkle root of the root ledger *)
val merkle_root : t -> root_hash

(** Make a checkpoint of the root ledger and return a new root ledger backed
      by that checkpoint. Throws an exception if the config does not match the
      backing type of the root.  *)
val create_checkpoint : t -> config:Config.t -> unit -> t

(** Make a checkpoint of the root ledger. Throws an exception if the config
      does not match the backing type of the root. *)
val make_checkpoint : t -> config:Config.t -> unit

(** Make a checkpoint of the root ledger [t] of the same backing type using
      [directory_name] as a template for its location. Return a new root ledger
      backed by that checkpoint. *)
val create_checkpoint_with_directory : t -> directory_name:string -> t

(** Convert a root backed by a [Config.Stable_db] to one backed by a
      [Config.Converting_db] by gradually migrating the stable database with a 
      designated hardfork slot. Only checks if the hardfork_slot is correct if 
      it's already having a [Config.Converting_db] instance. *)
val make_converting :
     hardfork_slot:Mina_numbers.Global_slot_since_genesis.t
  -> t
  -> t Async.Deferred.t

(** View the root ledger as an unmasked [Any_ledger] so it can be used by code
      that does not need to know how the root is implemented *)
val as_unmasked : t -> Ledger.Any_ledger.witness

(** Create a mask and attach it to the root *)
val as_masked : t -> Ledger.t

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

(** Decompose a root into its components parts. Users of this method must be
      careful to ensure that either the underlying databases remain in sync, or
      that they are not later used to back a root ledger. Use this on temporary
      copies of root ledgers if possible. *)
val unsafely_decompose_root : t -> Ledger.Db.t * Ledger.Hardfork_db.t option

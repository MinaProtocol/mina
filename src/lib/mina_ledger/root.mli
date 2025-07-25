open Core_kernel
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

module type Any_ledger_intf =
  Merkle_ledger.Intf.Ledger.ANY
    with type account := Account.t
     and type key := Signature_lib.Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type hash := Ledger_hash.t

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
                    and module Addr = Any_ledger.M.Addr) : sig
  type t

  type root_hash = Ledger_hash.t

  type hash = Ledger_hash.t

  type account = Account.t

  type addr = Stable_db.Addr.t

  type path = Stable_db.path

  (** Close the root ledger instance *)
  val close : t -> unit

  (** Retrieve the hash of the merkle root of the root ledger *)
  val merkle_root : t -> root_hash

  (** Create a root ledger backed by a single database in the given
      directory. *)
  val create_single : ?directory_name:string -> depth:int -> unit -> t

  (** Checkpoint the stable database backing the root and create a new
      [Stable_db.t] based on that checkpoint *)
  val create_checkpoint_stable :
    t -> directory_name:string -> unit -> Stable_db.t

  (** Make a checkpoint of the full root ledger *)
  val make_checkpoint : t -> directory_name:string -> unit

  (** View the root ledger as an unmasked [Any_ledger] so it can be used by code
      that does not need to know how the root is implemented *)
  val as_unmasked : t -> Any_ledger.witness

  (** Use the given [stable] account transfer method to transfer the accounts
      from one root ledger instance to another. For a root ledger backed by a
      single database (currently the only option) it is equivalent to using
      [stable] or a normal ledger transfer on the root. Future root backings
      should be able to support more efficient transfers (e.g., for a converting
      databases the accounts could be transferred directly between the
      underlying pair of databases)*)
  val transfer_accounts_with :
       stable:(src:Stable_db.t -> dest:Stable_db.t -> Stable_db.t Or_error.t)
    -> src:t
    -> dest:t
    -> t Or_error.t

  (** Retrieve the depth of the root ledger *)
  val depth : t -> int

  (** Retrieve the number of accounts in the root ledger *)
  val num_accounts : t -> int

  (** Calculate the address path from [addr] to the merkle root. *)
  val merkle_path_at_addr_exn : t -> addr -> path

  (** Get the hash at the given [addr] in the ledger. Throws an exception if the
      [addr] doesn't point to a hash. *)
  val get_inner_hash_at_addr_exn : t -> addr -> hash

  (** Calculate all the addresses that lie in the ledger, starting at [addr] and
      going downward in the merkle tree. Then, set the accounts at those
      addresses to the values in the list. Throws an exception if the [addr] is
      not in the ledger, or if there are not exactly enough accounts in the list
      to set the values at all the addresses. *)

  (* TODO: see if the hashes of the accounts can be passed in here too *)
  val set_all_accounts_rooted_at_exn : t -> addr -> account list -> unit

  (** For each addr-account pair, replace the account in the root with the given
      account. This is done as a single batch write. *)

  (* TODO: investigate if this can be removed from the syncable interface *)
  val set_batch_accounts : t -> (addr * account) list -> unit

  (** Get all of the accounts that are in a subtree of the underlying Merkle
    tree rooted at `address`. The accounts are ordered by their addresses. *)
  val get_all_accounts_rooted_at_exn : t -> addr -> (addr * account) list
end

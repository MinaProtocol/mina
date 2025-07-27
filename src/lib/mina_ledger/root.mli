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

  (** Close the root ledger instance *)
  val close : t -> unit

  (** Retrieve the hash of the merkle root of the root ledger *)
  val merkle_root : t -> Ledger_hash.t

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
end

open Core
open Async
open Signature_lib
open Mina_base

module Accounts : sig
  module Single : sig
    (** Convert a stable account and its optional private key into the
        [Runtime_config.Accounts.Single.t] JSON layout format *)
    val of_account :
      Account.t -> Private_key.t option -> Runtime_config.Accounts.Single.t
  end

  (** Parse an array of runtime config accounts and extract their private key
      and account data. Throws an exception if parsing fails. *)
  val to_full :
    Runtime_config.Accounts.t -> (Private_key.t option * Account.t) list
end

(** Update the [default] constraint constants value with any runtime config
    overrides *)
val make_constraint_constants :
     default:Genesis_constants.Constraint_constants.t
  -> Runtime_config.Proof_keys.t
  -> Genesis_constants.Constraint_constants.t

(** Update the [default] genesis constants value with any runtime config
    overrides *)
val make_genesis_constants :
     logger:Logger.t
  -> default:Genesis_constants.t
  -> Runtime_config.t
  -> Genesis_constants.t Or_error.t

exception Genesis_state_initialization_error

(** Compute and return the sha3-256 digest of the file at the [string] file
    path *)
val sha3_hash : string -> string Deferred.t

module Ledger : sig
  (** Create a genesis ledger database [tar.gz] file in [genesis_dir] from the
      contents of the directory at [ledger_dirname] and return a [string] path
      to the resulting file. The tar file name is of the form
      [<ledger_name_prefix_hash>_<hash>.tar.gz], where [hash] is derived from
      the input [root_hash] and the hash of an empty account in the current
      stable account format. This naming scheme is assumed by
      [init_from_config_file] when it attempts to find local genesis ledger
      database files.

      It is intended, but not checked, that [ledger_dirname] contain a
      [Mina_ledger.Ledger.Db.t], and that [root_hash] is that database's root
      hash.
  *)
  val generate_tar_stable :
       logger:Logger.t
    -> target_dir:string
    -> ledger_name_prefix:string
    -> root_hash:Ledger_hash.t
    -> ledger_dirname:string
    -> unit
    -> string Or_error.t Deferred.t

  (** Perform the same ledger database file creation as [generate_tar_stable],
      except for a [Mina_ledger.Ledger.Hardfork_db.t]. The difference is that
      the hash of the empty [Mina_base.Account.Hardfork.t] is used to compute
      the tar file name, to match what the version of [init_config_file] in a
      post-fork daemon expects. *)
  val generate_tar_hardfork :
       logger:Logger.t
    -> target_dir:string
    -> ledger_name_prefix:string
    -> root_hash:Ledger_hash.t
    -> ledger_dirname:string
    -> unit
    -> string Or_error.t Deferred.t

  (** Using [generate_tar_stable], create a genesis ledger database tar file in
      [genesis_dir] from the stable ledger database component of a
      [Mina_ledger.Root.t] and return a [string] path to the resulting file. The
      input [Mina_ledger.Ledger.t] is assumed to be a single (potentially
      uncommitted) mask over a [Mina_ledger.Root.t]. This method will commit
      this mask as a side effect of generating the tar files, to ensure the
      database is up-to-date. *)
  val generate_ledger_tar :
       genesis_dir:string
    -> logger:Logger.t
    -> ledger_name_prefix:string
    -> Mina_ledger.Ledger.t
    -> string Or_error.t Deferred.t

  (** Create a genesis ledger database in a temporary directory using the given
      list of accounts and return a [Genesis_ledger.Packed.t] interface to it.
      Note that the creation and population of the database, as well as the
      forcing of the input account list, is deferred until the returned lazy
      ledger is forced.

      The optional private keys in the list are ignored even if given. They are
      included so this method is compatible with the output type of
      [Accounts.to_full]. *)
  val packed_genesis_ledger_of_accounts :
       genesis_backing_type:Mina_ledger.Root.Config.backing_type
    -> logger:Logger.t
    -> depth:int
    -> (Private_key.t option * Account.t) list Lazy.t
    -> Genesis_ledger.Packed.t

  (** Take a JSON [Runtime_config.Ledger.t] and initialize a genesis ledger
      using its content. This method will create a new ledger database tar file
      if the ledger is given inline in the input. Otherwise, this method will
      fetch and cache a ledger database tar file that has been hosted remotely.
      Returns the genesis ledger, the input runtime ledger config, and the path
      to the database tar file. *)
  val load :
       proof_level:Genesis_constants.Proof_level.t
    -> genesis_dir:string
    -> logger:Logger.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> genesis_backing_type:Mina_ledger.Root.Config.backing_type
    -> ?ledger_name_prefix:string
    -> ?overwrite_version:Mina_numbers.Txn_version.t
    -> Runtime_config.Ledger.t
    -> (Genesis_ledger.Packed.t * Runtime_config.Ledger.t * string) Or_error.t
       Deferred.t
end

(** Read the file at the given [string] file path and return its [Yojson.Safe.t]
    file content *)
val load_config_json : string -> Yojson.Safe.t Or_error.t Deferred.t

(** Reconcile the given "base" genesis constants and a [Runtime_config.t] of
    overrides to those constants and return the result as a
    [Genesis_proof.Light.t]. This method computes these constants in exactly the
    same way as [init_from_config_file]. *)
val light_proof_from_runtime_config :
     logger:Logger.t
  -> cli_proof_level:Genesis_constants.Proof_level.t option
  -> genesis_constants:Genesis_constants.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> proof_level:Genesis_constants.Proof_level.t
  -> Runtime_config.t
  -> Genesis_proof.Light.t Or_error.t Deferred.t

(** Given specified "base" protocol constants and a [Runtime_config.t] of
    overrides to those constants, compute the actual constants to be used and
    return a full [Precomputed_values.t] with those constants. This method is
    also responsible for creating, finding, and/or downloading from S3 the
    genesis ledger databases, which will be initialized and included in the
    [Precomputed_values.t] by this method. *)
val init_from_config_file :
     cli_proof_level:Genesis_constants.Proof_level.t option
  -> genesis_constants:Genesis_constants.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> logger:Logger.t
  -> proof_level:Genesis_constants.Proof_level.t
  -> ?overwrite_version:Mina_numbers.Txn_version.t
  -> ?genesis_dir:string
  -> Runtime_config.t
  -> Precomputed_values.t Or_error.t Deferred.t

(** Upgrade a config file in the "old" format, where certain fields are expected
    to be at the top-level of the config object, to the current format, where
    these fields are expected to be children of the [daemon] field. This method
    expects a [string] path to the config file that the [Yojson.Safe.t] was read
    from and will attempt to update the file in-place if old fields are
    found. *)
val upgrade_old_config :
  logger:Logger.t -> string -> Yojson.Safe.t -> Yojson.Safe.t Deferred.t

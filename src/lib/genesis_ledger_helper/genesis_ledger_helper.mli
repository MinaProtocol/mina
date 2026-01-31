open Core
open Async
open Signature_lib
open Mina_base

module Accounts : sig
  module Single : sig
    val of_account :
      Account.t -> Private_key.t option -> Runtime_config.Accounts.Single.t
  end

  val to_full :
    Runtime_config.Accounts.t -> (Private_key.t option * Account.t) list
end

val make_constraint_constants :
     default:Genesis_constants.Constraint_constants.t
  -> Runtime_config.Proof_keys.t
  -> Genesis_constants.Constraint_constants.t

val make_genesis_constants :
     logger:Logger.t
  -> default:Genesis_constants.t
  -> Runtime_config.t
  -> Genesis_constants.t Or_error.t

exception Genesis_state_initialization_error

val sha3_hash : string -> string Deferred.t

module Ledger : sig
  val generate_tar_stable :
       logger:Logger.t
    -> target_dir:string
    -> ledger_name_prefix:string
    -> root_hash:Ledger_hash.t
    -> ledger_dirname:string
    -> unit
    -> string Or_error.t Deferred.t

  val generate_tar_hardfork :
       logger:Logger.t
    -> target_dir:string
    -> ledger_name_prefix:string
    -> root_hash:Ledger_hash.t
    -> ledger_dirname:string
    -> unit
    -> string Or_error.t Deferred.t

  val generate_ledger_tar :
       genesis_dir:string
    -> logger:Logger.t
    -> ledger_name_prefix:string
    -> Mina_ledger.Ledger.t
    -> string Or_error.t Deferred.t

  val packed_genesis_ledger_of_accounts :
       genesis_backing_type:Mina_ledger.Root.Config.backing_type
    -> logger:Logger.t
    -> depth:int
    -> (Private_key.t option * Account.t) list Lazy.t
    -> Genesis_ledger.Packed.t

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

val load_config_json : string -> Yojson.Safe.t Or_error.t Deferred.t

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

val upgrade_old_config :
  logger:Logger.t -> string -> Yojson.Safe.t -> Yojson.Safe.t Deferred.t

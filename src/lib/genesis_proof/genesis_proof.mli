open Mina_base
open Mina_state

module Inputs : sig
  type t =
    { runtime_config : Runtime_config.t
    ; constraint_constants : Genesis_constants.Constraint_constants.t
    ; proof_level : Genesis_constants.Proof_level.t
    ; genesis_constants : Genesis_constants.t
    ; genesis_ledger : Genesis_ledger.Packed.t
    ; genesis_epoch_data :
        Genesis_ledger.Packed.t Consensus.Genesis_data.Epoch.t
    ; genesis_body_reference : Consensus.Body_reference.t
    ; consensus_constants : Consensus.Constants.t
    ; protocol_state_with_hashes :
        Protocol_state.value State_hash.With_state_hashes.t
    ; constraint_system_digests : (string * Md5_lib.t) list option
    ; signature_kind : Mina_signature_kind.t
    }

  val runtime_config : t -> Runtime_config.t

  val constraint_constants : t -> Genesis_constants.Constraint_constants.t

  val genesis_constants : t -> Genesis_constants.t

  val proof_level : t -> Genesis_constants.Proof_level.t

  val protocol_constants : t -> Genesis_constants.Protocol.t

  val ledger_depth : t -> int

  val genesis_ledger : t -> Mina_ledger.Ledger.t Lazy.t

  val genesis_epoch_data :
    t -> Genesis_ledger.Packed.t Consensus.Genesis_data.Epoch.t

  val accounts :
    t -> (Signature_lib.Private_key.t option * Account.t) list Lazy.t

  val find_new_account_record_exn :
       t
    -> Signature_lib.Public_key.t list
    -> Signature_lib.Private_key.t option * Account.t

  val find_new_account_record_exn_ :
       t
    -> Signature_lib.Public_key.Compressed.t list
    -> Signature_lib.Private_key.t option * Account.t

  val largest_account_exn : t -> Signature_lib.Private_key.t option * Account.t

  val largest_account_keypair_exn : t -> Signature_lib.Keypair.t

  val largest_account_pk_exn : t -> Signature_lib.Public_key.Compressed.t

  val consensus_constants : t -> Consensus.Constants.t

  val genesis_state_with_hashes :
    t -> Protocol_state.value State_hash.With_state_hashes.t

  val genesis_state : t -> Protocol_state.value

  val genesis_state_hashes : t -> State_hash.State_hashes.t
end

module Proof_data : sig
  type t = { genesis_proof : Proof.t }
end

module T : sig
  type t =
    { runtime_config : Runtime_config.t
    ; constraint_constants : Genesis_constants.Constraint_constants.t
    ; genesis_constants : Genesis_constants.t
    ; proof_level : Genesis_constants.Proof_level.t
    ; genesis_ledger : Genesis_ledger.Packed.t
    ; genesis_epoch_data :
        Genesis_ledger.Packed.t Consensus.Genesis_data.Epoch.t
    ; genesis_body_reference : Consensus.Body_reference.t
    ; consensus_constants : Consensus.Constants.t
    ; protocol_state_with_hashes :
        Protocol_state.value State_hash.With_state_hashes.t
    ; constraint_system_digests : (string * Md5_lib.t) list Lazy.t
    ; proof_data : Proof_data.t option
    ; signature_kind : Mina_signature_kind.t
    }

  val runtime_config : t -> Runtime_config.t

  val constraint_constants : t -> Genesis_constants.Constraint_constants.t

  val genesis_constants : t -> Genesis_constants.t

  val proof_level : t -> Genesis_constants.Proof_level.t

  val protocol_constants : t -> Genesis_constants.Protocol.t

  val ledger_depth : t -> int

  include module type of Genesis_ledger.Utils

  val genesis_ledger : t -> Mina_ledger.Ledger.t Lazy.t

  val create_root :
       t
    -> config:Mina_ledger.Root.Config.t
    -> depth:int
    -> unit
    -> Mina_ledger.Root.t Async.Deferred.Or_error.t

  val genesis_epoch_data :
    t -> Genesis_ledger.Packed.t Consensus.Genesis_data.Epoch.t

  val accounts :
    t -> (Signature_lib.Private_key.t option * Account.t) list Lazy.t

  val find_new_account_record_exn :
       t
    -> Signature_lib.Public_key.t list
    -> Signature_lib.Private_key.t option * Account.t

  val find_new_account_record_exn_ :
       t
    -> Signature_lib.Public_key.Compressed.t list
    -> Signature_lib.Private_key.t option * Account.t

  val largest_account_exn : t -> Signature_lib.Private_key.t option * Account.t

  val largest_account_keypair_exn : t -> Signature_lib.Keypair.t

  val largest_account_pk_exn : t -> Signature_lib.Public_key.Compressed.t

  val consensus_constants : t -> Consensus.Constants.t

  val genesis_state_with_hashes :
    t -> Protocol_state.value State_hash.With_state_hashes.t

  val genesis_state : t -> Protocol_state.value

  val genesis_state_hashes : t -> State_hash.State_hashes.t

  val genesis_proof : t -> Proof.t option
end

include module type of T with type t = T.t

val create_values_no_proof : Inputs.t -> t

val to_inputs : t -> Inputs.t

(** A variant "light" genesis proof data type that contains everything that can
    be computed in a pure way based on the compile time and runtime config. *)
module Light : sig
  type t =
    { constraint_constants : Genesis_constants.Constraint_constants.t
    ; proof_level : Genesis_constants.Proof_level.t
    ; genesis_constants : Genesis_constants.t
    ; genesis_body_reference : Consensus.Body_reference.t
    ; consensus_constants : Consensus.Constants.t
    ; signature_kind : Mina_signature_kind.t
    }
end

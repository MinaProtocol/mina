open Core_kernel
open Mina_base
open Mina_state

module Inputs = struct
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
    ; blockchain_proof_system_id :
        (* This is only used for calculating the hash to lookup the genesis
           proof with. It is re-calculated when building the blockchain prover,
           so it is always okay -- if less efficient at startup -- to pass
           [None] here.
        *)
        Pickles.Verification_key.Id.t option
    ; signature_kind : Mina_signature_kind.t
    }

  let runtime_config { runtime_config; _ } = runtime_config

  let constraint_constants { constraint_constants; _ } = constraint_constants

  let genesis_constants { genesis_constants; _ } = genesis_constants

  let proof_level { proof_level; _ } = proof_level

  let protocol_constants t = (genesis_constants t).protocol

  let ledger_depth { genesis_ledger; _ } =
    Genesis_ledger.Packed.depth genesis_ledger

  include Genesis_ledger.Utils

  let genesis_ledger { genesis_ledger; _ } =
    Genesis_ledger.Packed.t genesis_ledger

  let genesis_epoch_data { genesis_epoch_data; _ } = genesis_epoch_data

  let accounts { genesis_ledger; _ } =
    Genesis_ledger.Packed.accounts genesis_ledger

  let find_new_account_record_exn { genesis_ledger; _ } =
    Genesis_ledger.Packed.find_new_account_record_exn genesis_ledger

  let find_new_account_record_exn_ { genesis_ledger; _ } =
    Genesis_ledger.Packed.find_new_account_record_exn_ genesis_ledger

  let largest_account_exn { genesis_ledger; _ } =
    Genesis_ledger.Packed.largest_account_exn genesis_ledger

  let largest_account_keypair_exn { genesis_ledger; _ } =
    Genesis_ledger.Packed.largest_account_keypair_exn genesis_ledger

  let largest_account_pk_exn { genesis_ledger; _ } =
    Genesis_ledger.Packed.largest_account_pk_exn genesis_ledger

  let consensus_constants { consensus_constants; _ } = consensus_constants

  let genesis_state_with_hashes { protocol_state_with_hashes; _ } =
    protocol_state_with_hashes

  let genesis_state t = (genesis_state_with_hashes t).data

  let genesis_state_hashes t = (genesis_state_with_hashes t).hash
end

module Proof_data = struct
  type t =
    { blockchain_proof_system_id : Pickles.Verification_key.Id.t
    ; genesis_proof : Proof.t
    }
end

module T = struct
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

  let runtime_config { runtime_config; _ } = runtime_config

  let constraint_constants { constraint_constants; _ } = constraint_constants

  let genesis_constants { genesis_constants; _ } = genesis_constants

  let proof_level { proof_level; _ } = proof_level

  let protocol_constants t = (genesis_constants t).protocol

  let ledger_depth { genesis_ledger; _ } =
    Genesis_ledger.Packed.depth genesis_ledger

  include Genesis_ledger.Utils

  let genesis_ledger { genesis_ledger; _ } =
    Genesis_ledger.Packed.t genesis_ledger

  let create_root { genesis_ledger; _ } =
    Genesis_ledger.Packed.create_root genesis_ledger

  let genesis_epoch_data { genesis_epoch_data; _ } = genesis_epoch_data

  let accounts { genesis_ledger; _ } =
    Genesis_ledger.Packed.accounts genesis_ledger

  let find_new_account_record_exn { genesis_ledger; _ } =
    Genesis_ledger.Packed.find_new_account_record_exn genesis_ledger

  let find_new_account_record_exn_ { genesis_ledger; _ } =
    Genesis_ledger.Packed.find_new_account_record_exn_ genesis_ledger

  let largest_account_exn { genesis_ledger; _ } =
    Genesis_ledger.Packed.largest_account_exn genesis_ledger

  let largest_account_keypair_exn { genesis_ledger; _ } =
    Genesis_ledger.Packed.largest_account_keypair_exn genesis_ledger

  let largest_account_pk_exn { genesis_ledger; _ } =
    Genesis_ledger.Packed.largest_account_pk_exn genesis_ledger

  let consensus_constants { consensus_constants; _ } = consensus_constants

  let genesis_state_with_hashes { protocol_state_with_hashes; _ } =
    protocol_state_with_hashes

  let genesis_state t = (genesis_state_with_hashes t).data

  let genesis_state_hashes t = (genesis_state_with_hashes t).hash

  let genesis_proof { proof_data; _ } =
    Option.map proof_data ~f:(fun { Proof_data.genesis_proof = p; _ } -> p)
end

include T

let constraint_system_digests ~signature_kind ~constraint_constants ~proof_level
    =
  lazy
    (let txn_digests =
       Transaction_snark.constraint_system_digests ~signature_kind
         ~constraint_constants ()
     in
     let blockchain_digests =
       Blockchain_snark.Blockchain_snark_state.constraint_system_digests
         ~proof_level ~constraint_constants ()
     in
     txn_digests @ blockchain_digests )

let create_values_no_proof (t : Inputs.t) =
  { runtime_config = t.runtime_config
  ; constraint_constants = t.constraint_constants
  ; proof_level = t.proof_level
  ; genesis_constants = t.genesis_constants
  ; genesis_ledger = t.genesis_ledger
  ; genesis_epoch_data = t.genesis_epoch_data
  ; genesis_body_reference = t.genesis_body_reference
  ; consensus_constants = t.consensus_constants
  ; protocol_state_with_hashes = t.protocol_state_with_hashes
  ; constraint_system_digests =
      constraint_system_digests ~signature_kind:t.signature_kind
        ~constraint_constants:t.constraint_constants ~proof_level:t.proof_level
  ; proof_data = None
  ; signature_kind = t.signature_kind
  }

let to_inputs (t : t) : Inputs.t =
  { runtime_config = t.runtime_config
  ; constraint_constants = t.constraint_constants
  ; proof_level = t.proof_level
  ; genesis_constants = t.genesis_constants
  ; genesis_ledger = t.genesis_ledger
  ; genesis_epoch_data = t.genesis_epoch_data
  ; genesis_body_reference = t.genesis_body_reference
  ; consensus_constants = t.consensus_constants
  ; protocol_state_with_hashes = t.protocol_state_with_hashes
  ; constraint_system_digests =
      ( if Lazy.is_val t.constraint_system_digests then
        Some (Lazy.force t.constraint_system_digests)
      else None )
  ; blockchain_proof_system_id =
      ( match t.proof_data with
      | Some { blockchain_proof_system_id; _ } ->
          Some blockchain_proof_system_id
      | None ->
          None )
  ; signature_kind = t.signature_kind
  }

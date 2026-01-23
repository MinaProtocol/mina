open Core
open Mina_base

module Inputs = struct
  type t =
    { genesis_state_hash : Data_hash_lib.State_hash.t
    ; genesis_constants : Genesis_constants.t
    ; constraint_system_digests : (string * Md5_lib.t) list Lazy.t
    ; protocol_transaction_version : int
    ; protocol_network_version : int
    }
end

let of_inputs (inputs : Inputs.t) =
  (* if this changes, also change Mina_commands.chain_id_inputs *)
  let genesis_state_hash =
    State_hash.to_base58_check inputs.genesis_state_hash
  in
  let genesis_constants_hash =
    Genesis_constants.hash inputs.genesis_constants
  in
  let all_snark_keys =
    List.map (Lazy.force inputs.constraint_system_digests)
      ~f:(fun (_, digest) -> Md5.to_hex digest)
    |> String.concat ~sep:""
  in
  let version_digest v = Int.to_string v |> Md5.digest_string |> Md5.to_hex in
  let protocol_transaction_version_digest =
    version_digest inputs.protocol_transaction_version
  in
  let protocol_network_version_digest =
    version_digest inputs.protocol_network_version
  in
  let b2 =
    Blake2.digest_string
      ( genesis_state_hash ^ all_snark_keys ^ genesis_constants_hash
      ^ protocol_transaction_version_digest ^ protocol_network_version_digest )
  in
  Blake2.to_hex b2

type t = string [@@deriving equal]

let to_string t = t

let make ~signature_kind ~(genesis_constants : Genesis_constants.t)
    ~constraint_constants ~proof_level ~genesis_ledger
    ~(genesis_epoch_data :
       Consensus.Genesis_data.Hashed.t Consensus.Genesis_data.Epoch.t ) =
  let consensus_constants =
    Consensus.Constants.create ~constraint_constants
      ~protocol_constants:genesis_constants.protocol
  in
  let protocol_state_with_hashes =
    Mina_state.Genesis_protocol_state.t
      ~genesis_ledger:
        (Consensus.Genesis_data.Hashed.zero_total_currency genesis_ledger)
      ~genesis_epoch_data:
        (Consensus.Genesis_data.Epoch.zero_total_currency genesis_epoch_data)
      ~constraint_constants ~consensus_constants
      ~genesis_body_reference:Staged_ledger_diff.genesis_body_reference
  in
  of_inputs
    { Inputs.genesis_state_hash = protocol_state_with_hashes.hash.state_hash
    ; genesis_constants
    ; constraint_system_digests =
        Genesis_proof.constraint_system_digests ~signature_kind ~proof_level
          ~constraint_constants
    ; protocol_transaction_version = Protocol_version.(transaction current)
    ; protocol_network_version = Protocol_version.(network current)
    }

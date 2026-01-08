open Core
open Mina_base

type inputs =
  { genesis_state_hash : Data_hash_lib.State_hash.t
  ; genesis_constants : Genesis_constants.t
  ; constraint_system_digests : (string * Md5_lib.t) list
  ; protocol_transaction_version : int
  ; protocol_network_version : int
  }

type t = string

(* keep this code in sync with Client.chain_id_inputs, Mina_commands.chain_id_inputs, and
   Daemon_rpcs.Chain_id_inputs
*)
let make inputs =
  (* if this changes, also change Mina_commands.chain_id_inputs *)
  let genesis_state_hash =
    State_hash.to_base58_check inputs.genesis_state_hash
  in
  let genesis_constants_hash =
    Genesis_constants.hash inputs.genesis_constants
  in
  let all_snark_keys =
    List.map inputs.constraint_system_digests ~f:(fun (_, digest) ->
        Md5.to_hex digest )
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

let to_string t = t

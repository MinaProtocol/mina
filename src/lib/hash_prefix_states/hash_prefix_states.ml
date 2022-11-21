open Core_kernel
open Hash_prefixes

let salt (s : Hash_prefixes.t) = Random_oracle.salt (s :> string)

let salt_legacy (s : Hash_prefixes.t) = Random_oracle.Legacy.salt (s :> string)

let receipt_chain_signed_command = salt_legacy receipt_chain_user_command

let receipt_chain_zkapp_command = salt receipt_chain_user_command

let receipt_chain_zkapp = salt receipt_chain_zkapp

let coinbase = salt coinbase

let pending_coinbases = salt pending_coinbases

let coinbase_stack_data = salt coinbase_stack_data

let coinbase_stack_state_hash = salt coinbase_stack_state_hash

let coinbase_stack = salt coinbase_stack

let checkpoint_list = salt checkpoint_list

let merge_snark = salt merge_snark

let base_snark = salt base_snark

let protocol_state = salt protocol_state

let protocol_state_body = salt protocol_state_body

let merkle_tree =
  let f i = salt (merkle_tree i) in
  (* Cache up to the compiled ledger depth. *)
  let cached = ref [||] in
  fun i ->
    let len = Array.length !cached in
    if i >= len then
      cached :=
        Array.append !cached
          (Array.init (i + 1 - len) ~f:(fun i -> f (i + len))) ;
    !cached.(i)

let coinbase_merkle_tree =
  let f i = salt (coinbase_merkle_tree i) in
  let cached = ref [||] in
  fun i ->
    let len = Array.length !cached in
    if i >= len then
      cached :=
        Array.append !cached
          (Array.init (i + 1 - len) ~f:(fun i -> f (i + len))) ;
    !cached.(i)

let vrf_message = salt vrf_message

let signature_for_mainnet = salt signature_mainnet

let signature_for_testnet = salt signature_testnet

let signature =
  match Mina_signature_kind.t with
  | Mainnet ->
      signature_for_mainnet
  | Testnet ->
      signature_for_testnet

let signature_for_mainnet_legacy = salt_legacy signature_mainnet

let signature_for_testnet_legacy = salt_legacy signature_testnet

let signature_legacy =
  match Mina_signature_kind.t with
  | Mainnet ->
      signature_for_mainnet_legacy
  | Testnet ->
      signature_for_testnet_legacy

let vrf_output = salt vrf_output

let vrf_evaluation = salt vrf_evaluation

let epoch_seed = salt epoch_seed

let transition_system_snark = salt transition_system_snark

let account = salt account

let side_loaded_vk = salt side_loaded_vk

let zkapp_account = salt zkapp_account

let zkapp_payload = salt zkapp_payload

let zkapp_body = salt zkapp_body

let zkapp_precondition = salt zkapp_precondition

let zkapp_precondition_account = salt zkapp_precondition_account

let zkapp_precondition_protocol_state = salt zkapp_precondition_protocol_state

let account_update = salt account_update

let account_update_account_precondition =
  salt account_update_account_precondition

let account_update_cons = salt account_update_cons

let account_update_node = salt account_update_node

let account_update_stack_frame = salt account_update_stack_frame

let account_update_stack_frame_cons = salt account_update_stack_frame_cons

let zkapp_uri = salt zkapp_uri

let zkapp_event = salt zkapp_event

let zkapp_events = salt zkapp_events

let zkapp_sequence_events = salt zkapp_sequence_events

let zkapp_memo = salt zkapp_memo

let zkapp_test = salt zkapp_test

let derive_token_id = salt derive_token_id

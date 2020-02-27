[%%import
"/src/config.mlh"]

[%%ifdef
consensus_mechanism]

open Snark_params

[%%else]

open Snark_params_nonconsensus
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

open Core_kernel
open Hash_prefixes
open Scan_state_constants

let salt (s : Hash_prefixes.t) = Random_oracle.salt (s :> string)

let receipt_chain = salt receipt_chain

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

let merkle_tree = Array.init ledger_depth ~f:(fun i -> salt (merkle_tree i))

let coinbase_merkle_tree =
  Array.init pending_coinbase_depth ~f:(fun i -> salt (coinbase_merkle_tree i))

let vrf_message = salt vrf_message

let signature = salt signature

let vrf_output = salt vrf_output

let epoch_seed = salt epoch_seed

let transition_system_snark = salt transition_system_snark

let account = salt account

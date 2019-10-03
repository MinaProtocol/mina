open Core_kernel
open Hash_prefixes

let length_in_triples = length_in_triples

let salt (s : t) = Snark_params.Tick.Pedersen.(State.salt (s :> string))

let account = salt account

let receipt_chain = salt receipt_chain

let coinbase = salt coinbase

let pending_coinbases = salt pending_coinbases

let coinbase_stack = salt coinbase_stack

let checkpoint_list = salt checkpoint_list

let merge_snark = salt merge_snark

let base_snark = salt base_snark

module Random_oracle = struct
  let salt (s : Hash_prefixes.t) = Random_oracle.salt (s :> string)

  let protocol_state = salt protocol_state

  let protocol_state_body = salt protocol_state_body

  let merkle_tree =
    Array.init Snark_params.ledger_depth ~f:(fun i -> salt (merkle_tree i))

  let coinbase_merkle_tree =
    Array.init Snark_params.pending_coinbase_depth ~f:(fun i ->
        salt (coinbase_merkle_tree i) )

  let vrf_message = salt vrf_message

  let signature = salt signature

  let vrf_output = salt vrf_output

  let epoch_seed = salt epoch_seed

  let transition_system_snark = salt transition_system_snark
end

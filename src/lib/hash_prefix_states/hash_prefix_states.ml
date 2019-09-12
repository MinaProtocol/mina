open Core_kernel
open Hash_prefixes

let length_in_triples = length_in_triples

let salt (s : t) = Snark_params.Tick.Pedersen.(State.salt (s :> string))

let protocol_state = salt protocol_state

let protocol_state_body = salt protocol_state_body

let account = salt account

let proof_of_work = salt proof_of_work

let merge_snark = salt merge_snark

let base_snark = salt base_snark

let transition_system_snark = salt transition_system_snark

let receipt_chain = salt receipt_chain

let coinbase = salt coinbase

let pending_coinbases = salt pending_coinbases

let coinbase_stack = salt coinbase_stack

let checkpoint_list = salt checkpoint_list

module Random_oracle = struct
  let prefix_to_field (s : Hash_prefixes.t) =
    let open Snark_params.Tick in
    let s = (s :> string) in
    assert (8 * String.length s < Field.size_in_bits) ;
    Snark_params.Tick.Field.project
      Fold_lib.Fold.(to_list (string_bits (s :> string)))

  let salt (s : Hash_prefixes.t) =
    Random_oracle.(update ~state:initial_state [|prefix_to_field s|])

  let merkle_tree =
    Array.init Snark_params.ledger_depth ~f:(fun i -> salt (merkle_tree i))

  let%test_unit "rescue salt" =
    let open Snark_params in
    let open Tick in
    let x = Field.random () in
    let y = Field.random () in
    [%test_eq: Field.t Random_oracle.State.t]
      (Random_oracle.update ~state:merkle_tree.(0) [|x; y|])
      (Random_oracle.update ~state:Random_oracle.initial_state
         [|prefix_to_field (Hash_prefixes.merkle_tree 0); Field.zero; x; y|])

  let coinbase_merkle_tree =
    Array.init Snark_params.pending_coinbase_depth ~f:(fun i ->
        salt (coinbase_merkle_tree i) )

  let vrf_message = salt vrf_message

  let signature = salt signature

  let vrf_output = salt vrf_output

  let epoch_seed = salt epoch_seed
end

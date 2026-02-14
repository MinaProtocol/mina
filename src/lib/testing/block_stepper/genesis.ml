open Core
open Async
open Mina_state

let create_genesis_proof m ~constraint_constants
    (genesis_inputs : Genesis_proof.Inputs.t) =
  (* Copied from block_producer.ml *)
  let ( blockchain
      , protocol_state
      , snark_transition
      , ledger_proof_opt
      , prover_state
      , pending_coinbase ) =
    Prover.create_genesis_block_inputs genesis_inputs
  in
  Block_builder.extend_blockchain m ~constraint_constants blockchain
    protocol_state snark_transition ledger_proof_opt prover_state
    pending_coinbase

let create_genesis_breadcrumb ~logger ~precomputed_values ~root_ledger
    keys_module () =
  let constraint_constants =
    precomputed_values.Precomputed_values.constraint_constants
  in
  let (module Keys : Block_builder.Keys_S) = keys_module in
  [%log info] "Generating genesis proof" ;
  let%map real_proof =
    create_genesis_proof
      (module Keys.B)
      ~constraint_constants
      (Genesis_proof.to_inputs precomputed_values)
    >>| Or_error.ok_exn >>| Blockchain_snark.Blockchain.proof
  in
  let genesis_state =
    Precomputed_values.genesis_state_with_hashes precomputed_values
  in
  let protocol_state = With_hash.data genesis_state in
  let header =
    Mina_block.Header.create ~protocol_state ~protocol_state_proof:real_proof
      ~delta_block_chain_proof:
        (Protocol_state.previous_state_hash protocol_state, [])
      ()
  in
  let body = Mina_block.Body.create Staged_ledger_diff.empty_diff in
  let block = Mina_block.create ~header ~body in
  let block_with_hash = With_hash.map genesis_state ~f:(Fn.const block) in
  let validation =
    ( (`Time_received, Mina_stdlib.Truth.True ())
    , (`Genesis_state, Mina_stdlib.Truth.True ())
    , (`Proof, Mina_stdlib.Truth.True ())
    , ( `Delta_block_chain
      , Mina_stdlib.Truth.True
          ( Mina_stdlib.Nonempty_list.singleton
          @@ Protocol_state.previous_state_hash protocol_state ) )
    , (`Frontier_dependencies, Mina_stdlib.Truth.True ())
    , (`Staged_ledger_diff, Mina_stdlib.Truth.True ())
    , (`Protocol_versions, Mina_stdlib.Truth.True ()) )
  in
  let validated = Mina_block.Validated.lift (block_with_hash, validation) in
  let mask =
    Mina_ledger.Ledger.Mask.create ~depth:constraint_constants.ledger_depth ()
  in
  let ledger = Mina_ledger.Ledger.Maskable.register_mask root_ledger mask in
  let staged_ledger = Staged_ledger.create_exn ~constraint_constants ~ledger in
  let accounts_created =
    Precomputed_values.accounts precomputed_values
    |> Lazy.force
    |> List.map ~f:Precomputed_values.id_of_account_record
  in
  [%log info] "Creating genesis breadcrumb" ;
  Frontier_base.Breadcrumb.create ~validated_transition:validated ~staged_ledger
    ~transition_receipt_time:(Some (Time.now ()))
    ~just_emitted_a_proof:false ~accounts_created

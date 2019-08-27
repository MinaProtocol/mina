open Core_kernel
open Coda_base

let create_with_custom_ledger ~genesis_consensus_state ~genesis_ledger =
  let negative_one_protocol_state_hash =
    Protocol_state.(hash (Lazy.force negative_one))
  in
  let root_ledger_hash = Ledger.merkle_root genesis_ledger in
  let staged_ledger_hash =
    Staged_ledger_hash.of_aux_ledger_and_coinbase_hash
      Staged_ledger_hash.Aux_hash.dummy root_ledger_hash
      (Or_error.ok_exn (Pending_coinbase.create ()))
  in
  let snarked_ledger_hash =
    Frozen_ledger_hash.of_ledger_hash root_ledger_hash
  in
  let blockchain_state =
    Blockchain_state.create_value
      ~timestamp:Blockchain_state.(timestamp (Lazy.force genesis))
      ~staged_ledger_hash ~snarked_ledger_hash
  in
  let state =
    Protocol_state.create_value
      ~previous_state_hash:negative_one_protocol_state_hash ~blockchain_state
      ~consensus_state:genesis_consensus_state
  in
  With_hash.of_data ~hash_data:Protocol_state.hash state

let t =
  lazy
    (let negative_one_protocol_state_hash =
       Protocol_state.(hash @@ Lazy.force negative_one)
     in
     let genesis_consensus_state =
       Consensus.Data.Consensus_state.create_genesis
         ~negative_one_protocol_state_hash
     in
     let state =
       Protocol_state.create_value
         ~previous_state_hash:negative_one_protocol_state_hash
         ~blockchain_state:(Lazy.force Blockchain_state.genesis)
         ~consensus_state:genesis_consensus_state
     in
     With_hash.of_data ~hash_data:Protocol_state.hash state)

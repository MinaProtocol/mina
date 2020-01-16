open Core_kernel
open Coda_base

let create_with_custom_ledger ~genesis_consensus_state ~genesis_ledger =
  let negative_one_protocol_state_hash =
    Protocol_state.(hash (negative_one ~genesis_ledger))
  in
  let root_ledger_hash = Ledger.merkle_root (Lazy.force genesis_ledger) in
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
      ~timestamp:
        Blockchain_state.(
          timestamp (genesis ~genesis_ledger_hash:root_ledger_hash))
      ~staged_ledger_hash ~snarked_ledger_hash
  in
  let state =
    Protocol_state.create_value
      ~genesis_state_hash:
        (State_hash.of_hash Snark_params.Tick.Pedersen.zero_hash)
      ~previous_state_hash:negative_one_protocol_state_hash ~blockchain_state
      ~consensus_state:genesis_consensus_state
  in
  With_hash.of_data ~hash_data:Protocol_state.hash state

let t ~genesis_ledger =
  let genesis_ledger_hash = Ledger.merkle_root (Lazy.force genesis_ledger) in
  let negative_one_protocol_state_hash =
    Protocol_state.(hash (negative_one ~genesis_ledger))
  in
  let genesis_consensus_state =
    Consensus.Data.Consensus_state.create_genesis
      ~negative_one_protocol_state_hash ~genesis_ledger
  in
  let state =
    Protocol_state.create_value
      ~genesis_state_hash:negative_one_protocol_state_hash
      ~previous_state_hash:negative_one_protocol_state_hash
      ~blockchain_state:(Blockchain_state.genesis ~genesis_ledger_hash)
      ~consensus_state:genesis_consensus_state
  in
  With_hash.of_data ~hash_data:Protocol_state.hash state

let compile_time_genesis () = t ~genesis_ledger:Test_genesis_ledger.t

module For_tests = struct
  (*Use test_ledger generated at compile time*)
  let genesis_state_hash () =
    t ~genesis_ledger:Test_genesis_ledger.t |> With_hash.hash
end

open Core_kernel
open Coda_base

let t ~genesis_ledger ~constraint_constants ~consensus_constants =
  let genesis_ledger_hash = Ledger.merkle_root (Lazy.force genesis_ledger) in
  let protocol_constants =
    Consensus.Constants.to_protocol_constants consensus_constants
  in
  let negative_one_protocol_state_hash =
    Protocol_state.(
      hash
        (negative_one ~genesis_ledger ~constraint_constants
           ~consensus_constants))
  in
  let genesis_consensus_state =
    Consensus.Data.Consensus_state.create_genesis
      ~negative_one_protocol_state_hash ~genesis_ledger ~constraint_constants
      ~constants:consensus_constants
  in
  let state =
    Protocol_state.create_value
      ~genesis_state_hash:negative_one_protocol_state_hash
      ~previous_state_hash:negative_one_protocol_state_hash
      ~blockchain_state:
        (Blockchain_state.genesis ~constraint_constants ~genesis_ledger_hash)
      ~consensus_state:genesis_consensus_state ~constants:protocol_constants
  in
  With_hash.of_data ~hash_data:Protocol_state.hash state

module For_tests = struct
  (*Use test_ledger generated at compile time*)

  let genesis_state =
    lazy
      (t ~genesis_ledger:Test_genesis_ledger.t
         ~constraint_constants:
           Genesis_constants.Constraint_constants.for_unit_tests
         ~consensus_constants:(Lazy.force Consensus.Constants.for_unit_tests))

  let genesis_state_hash = Lazy.map ~f:With_hash.hash genesis_state
end

open Core_kernel
open Coda_base

let t ~genesis_ledger ~(runtime_config : Runtime_config.t) =
  let genesis_ledger_hash = Ledger.merkle_root (Lazy.force genesis_ledger) in
  let protocol_config = runtime_config.protocol in
  let negative_one_protocol_state_hash =
    Protocol_state.(hash (negative_one ~genesis_ledger ~protocol_config))
  in
  let genesis_consensus_state =
    Consensus.Data.Consensus_state.create_genesis
      ~negative_one_protocol_state_hash ~genesis_ledger ~protocol_config
  in
  let state =
    Protocol_state.create_value
      ~genesis_state_hash:negative_one_protocol_state_hash
      ~previous_state_hash:negative_one_protocol_state_hash
      ~blockchain_state:(Blockchain_state.genesis ~genesis_ledger_hash)
      ~consensus_state:genesis_consensus_state
      ~constants:(Protocol_constants_checked.value_of_t protocol_config)
  in
  With_hash.of_data ~hash_data:Protocol_state.hash state

let for_unit_tests =
  lazy
    (t ~genesis_ledger:Genesis_ledger.Unit_test_ledger.t
       ~runtime_config:Runtime_config.for_unit_tests)

module For_tests = struct
  let unit_test_genesis_state_hash = Lazy.map ~f:With_hash.hash for_unit_tests
end

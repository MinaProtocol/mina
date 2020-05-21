open Core_kernel
open Coda_base

let t ~genesis_ledger ~constraint_constants
    ~(genesis_constants : Genesis_constants.t) =
  let genesis_ledger_hash = Ledger.merkle_root (Lazy.force genesis_ledger) in
  let protocol_constants = genesis_constants.protocol in
  let negative_one_protocol_state_hash =
    Protocol_state.(
      hash
        (negative_one ~genesis_ledger ~constraint_constants ~protocol_constants))
  in
  let genesis_consensus_state =
    Consensus.Data.Consensus_state.create_genesis
      ~negative_one_protocol_state_hash ~genesis_ledger ~constraint_constants
      ~protocol_constants
  in
  let state =
    Protocol_state.create_value
      ~genesis_state_hash:negative_one_protocol_state_hash
      ~previous_state_hash:negative_one_protocol_state_hash
      ~blockchain_state:
        (Blockchain_state.genesis ~constraint_constants ~genesis_ledger_hash)
      ~consensus_state:genesis_consensus_state
      ~constants:(Protocol_constants_checked.value_of_t protocol_constants)
  in
  With_hash.of_data ~hash_data:Protocol_state.hash state

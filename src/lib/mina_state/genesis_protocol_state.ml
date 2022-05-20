open Core_kernel

let t ~genesis_ledger ~genesis_epoch_data ~constraint_constants
    ~consensus_constants =
  let genesis_ledger_hash =
    Mina_ledger.Ledger.merkle_root (Lazy.force genesis_ledger)
  in
  let protocol_constants =
    Consensus.Constants.to_protocol_constants consensus_constants
  in
  let negative_one_protocol_state_hash =
    Protocol_state.(
      hashes
        (negative_one ~genesis_ledger ~genesis_epoch_data ~constraint_constants
           ~consensus_constants ))
      .state_hash
  in
  let genesis_consensus_state =
    Consensus.Data.Consensus_state.create_genesis
      ~negative_one_protocol_state_hash ~genesis_ledger ~genesis_epoch_data
      ~constraint_constants ~constants:consensus_constants
  in
  let state =
    Protocol_state.create_value
      ~genesis_state_hash:negative_one_protocol_state_hash
      ~previous_state_hash:
        (Option.value_map constraint_constants.fork
           ~default:negative_one_protocol_state_hash
           ~f:(fun { previous_state_hash; _ } -> previous_state_hash) )
      ~blockchain_state:
        (Blockchain_state.genesis ~constraint_constants ~consensus_constants
           ~genesis_ledger_hash )
      ~consensus_state:genesis_consensus_state ~constants:protocol_constants
  in
  With_hash.of_data ~hash_data:Protocol_state.hashes state

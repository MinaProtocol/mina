open Core_kernel

let t ~genesis_ledger ~genesis_epoch_data ~constraint_constants
    ~consensus_constants ~genesis_body_reference =
  let genesis_ledger_forced =
    Lazy.force @@ Genesis_ledger.Packed.t genesis_ledger
  in
  let genesis_ledger_hash =
    Mina_ledger.Ledger.merkle_root genesis_ledger_forced
  in
  let protocol_constants =
    Consensus.Constants.to_protocol_constants consensus_constants
  in
  let negative_one_protocol_state_hash =
    Protocol_state.(
      hashes
        (negative_one ~genesis_ledger ~genesis_epoch_data ~constraint_constants
           ~consensus_constants ~genesis_body_reference ))
      .state_hash
  in
  let genesis_epoch_data =
    Consensus.Genesis_epoch_data.hashed_of_full genesis_epoch_data
  in
  let total_currency =
    Genesis_ledger.Packed.t genesis_ledger
    |> Consensus.genesis_ledger_total_currency
  in
  let genesis_consensus_state =
    Consensus.Data.Consensus_state.create_genesis
      ~negative_one_protocol_state_hash ~genesis_ledger_hash ~genesis_epoch_data
      ~constraint_constants ~constants:consensus_constants ~total_currency
  in
  let state =
    Protocol_state.create_value
      ~genesis_state_hash:negative_one_protocol_state_hash
      ~previous_state_hash:
        (Option.value_map constraint_constants.fork
           ~default:negative_one_protocol_state_hash
           ~f:(fun { state_hash; _ } -> state_hash) )
      ~blockchain_state:
        (Blockchain_state.genesis ~constraint_constants ~consensus_constants
           ~genesis_ledger_hash ~genesis_body_reference )
      ~consensus_state:genesis_consensus_state ~constants:protocol_constants
  in
  With_hash.of_data ~hash_data:Protocol_state.hashes state

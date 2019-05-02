let t =
  let negative_one_protocol_state_hash = Protocol_state.(hash negative_one) in
  let genesis_consensus_state =
    Consensus.Data.Consensus_state.create_genesis
      ~negative_one_protocol_state_hash
  in
  let state =
    Protocol_state.create_value
      ~previous_state_hash:negative_one_protocol_state_hash
      ~blockchain_state:Blockchain_state.genesis
      ~consensus_state:genesis_consensus_state
  in
  With_hash.of_data ~hash_data:Protocol_state.hash state

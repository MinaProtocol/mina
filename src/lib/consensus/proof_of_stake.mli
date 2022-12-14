include
  Proof_of_stake_intf.Full
    with type Data.Consensus_state.Value.Stable.V1.t =
      Mina_wire_types.Consensus_proof_of_stake.Data.Consensus_state.Value.V1.t

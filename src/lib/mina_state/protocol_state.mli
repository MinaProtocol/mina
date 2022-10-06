include
  Protocol_state_intf.Full
    with type ( 'state_hash
              , 'blockchain_state
              , 'consensus_state
              , 'constants )
              Body.Poly.Stable.V1.t =
      ( 'state_hash
      , 'blockchain_state
      , 'consensus_state
      , 'constants )
      Mina_wire_types.Mina_state.Protocol_state.Body.Poly.V1.t
     and type Body.Value.Stable.V2.t =
      Mina_wire_types.Mina_state.Protocol_state.Body.Value.V2.t

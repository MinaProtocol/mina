include
  Snarked_ledger_state_intf.Full
    with type ( 'ledger_hash
              , 'amount
              , 'pending_coinbase
              , 'fee_excess
              , 'sok_digest
              , 'local_state )
              Poly.Stable.V3.t =
      ( 'ledger_hash
      , 'amount
      , 'pending_coinbase
      , 'fee_excess
      , 'sok_digest
      , 'local_state )
      Mina_wire_types.Mina_state.Snarked_ledger_state.Poly.V3.t

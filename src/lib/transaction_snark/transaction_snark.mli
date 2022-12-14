include
  Transaction_snark_intf.Full
    with type ( 'ledger_hash
              , 'amount
              , 'pending_coinbase
              , 'fee_excess
              , 'sok_digest
              , 'local_state )
              Statement.Poly.Stable.V2.t =
      ( 'ledger_hash
      , 'amount
      , 'pending_coinbase
      , 'fee_excess
      , 'sok_digest
      , 'local_state )
      Mina_wire_types.Transaction_snark.Statement.Poly.V2.t
     and type Stable.V2.t = Mina_wire_types.Transaction_snark.V2.t

include
  Staged_ledger_hash_intf.Full
    with type Aux_hash.t =
      Mina_wire_types.Mina_base.Staged_ledger_hash.Aux_hash.t
     and type Pending_coinbase_aux.t =
      Mina_wire_types.Mina_base.Staged_ledger_hash.Pending_coinbase_aux.V1.t
     and type t = Mina_wire_types.Mina_base.Staged_ledger_hash.V1.t
     and type Stable.V1.t = Mina_wire_types.Mina_base.Staged_ledger_hash.V1.t

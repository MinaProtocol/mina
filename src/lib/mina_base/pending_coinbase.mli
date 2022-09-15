include
  Pending_coinbase_intf.S
    with type State_stack.Stable.V1.t =
      Mina_wire_types.Mina_base.Pending_coinbase.State_stack.V1.t
     and type Stack_versioned.Stable.V1.t =
      Mina_wire_types.Mina_base.Pending_coinbase.Stack_versioned.V1.t

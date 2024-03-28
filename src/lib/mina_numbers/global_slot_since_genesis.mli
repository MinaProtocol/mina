include
  Global_slot_intf.S
    with type Stable.V1.t =
      Mina_wire_types.Mina_numbers.Global_slot_since_genesis.V1.t
     and type global_slot_span =
      Mina_wire_types.Mina_numbers.Global_slot_span.V1.t
     and type Checked.global_slot_span_checked = Global_slot_span.Checked.t

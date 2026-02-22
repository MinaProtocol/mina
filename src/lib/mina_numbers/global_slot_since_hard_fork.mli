include
  Global_slot_intf.S
    with type Stable.V1.t =
      Mina_wire_types.Mina_numbers.Global_slot_since_hard_fork.V1.t
     and type global_slot_span =
      Mina_wire_types.Mina_numbers.Global_slot_span.V1.t
     and type Checked.global_slot_span_checked = Global_slot_span.Checked.t

val to_global_slot_since_genesis :
     current_genesis_global_slot:Global_slot_since_genesis.t option
  -> t
  -> Global_slot_since_genesis.t

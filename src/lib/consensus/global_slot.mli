include
  Global_slot_intf.Full
    with type ('slot_number, 'slots_per_epoch) Poly.Stable.V1.t =
      ( 'slot_number
      , 'slots_per_epoch )
      Mina_wire_types.Consensus_global_slot.Poly.V1.t
     and type Stable.V1.t = Mina_wire_types.Consensus_global_slot.V1.t

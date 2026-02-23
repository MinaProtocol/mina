(* 32-bit ordinals *)

include
  Nat.Intf.UInt32_A
    with type Stable.V1.t = Mina_wire_types.Mina_numbers.Index.V1.t

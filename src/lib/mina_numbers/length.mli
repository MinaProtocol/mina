include
  Nat.Intf.UInt32_A
    with type Stable.V1.t = Mina_wire_types.Mina_numbers.Length.V1.t

(** Returns pred of the blockchain length or zero in case of zero *)
val pred : t -> t
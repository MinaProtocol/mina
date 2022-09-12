include
  Nat.Intf.UInt32_A
    with type Stable.V1.t = Mina_wire_types.Mina_numbers.Account_nonce.V1.t

include Codable.S with type t := t

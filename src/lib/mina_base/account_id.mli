include
  Account_id_intf.S
    with type Digest.Stable.V1.t =
      Mina_wire_types.Mina_base.Account_id.Digest.V1.t
     and type Stable.V2.t = Mina_wire_types.Mina_base.Account_id.V2.t

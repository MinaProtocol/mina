include
  Pickles_intf.S
    with type Side_loaded.Verification_key.Stable.V2.t =
      Mina_wire_types.Pickles.Side_loaded.Verification_key.V2.t
     and type 'a Proof.t = 'a Mina_wire_types.Pickles.Proof.t

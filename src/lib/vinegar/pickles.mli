include
  Vinegar_intf.S
    with type Side_loaded.Verification_key.Stable.V2.t =
      Mina_wire_types.Vinegar.Side_loaded.Verification_key.V2.t
     and type ('a, 'b) Proof.t = ('a, 'b) Mina_wire_types.Vinegar.Proof.t

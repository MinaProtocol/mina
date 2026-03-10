include
  Intf.Full
    with type fp := Kimchi_pasta_basic.Fp.t
    with type field_var := Kimchi_pasta_basic.Fp.t Snarky_backendless.Cvar.t
     and type gates := Kimchi_bindings.Protocol.Gates.Vector.Fp.t

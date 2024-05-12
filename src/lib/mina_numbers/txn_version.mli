include
  Nat.Intf.UInt32_A
    with type Stable.V1.t = Mina_wire_types.Mina_numbers.Txn_version.V1.t

val equal_to_current : current:t -> t -> bool

val older_than_current : current:t -> t -> bool

val equal_to_current_checked :
     current:Checked.t
  -> Checked.t
  -> Snark_params.Tick.Boolean.var Snark_params.Tick.Checked.t

val older_than_current_checked :
     current:Checked.t
  -> Checked.t
  -> Snark_params.Tick.Boolean.var Snark_params.Tick.Checked.t

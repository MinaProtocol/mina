include
  Nat.Intf.UInt32_A
    with type Stable.V1.t = Mina_wire_types.Mina_numbers.Txn_version.V1.t

val current : t

(** The transaction version of the Mesa upgrade. This is frozen, unlike
    {!current}, which moves with each upgrade. *)
val mesa : t

val equal_to_current : t -> bool

val older_than_current : t -> bool

val current_checked : Checked.t

val equal_to_current_checked :
  Checked.t -> Snark_params.Tick.Boolean.var Snark_params.Tick.Checked.t

val older_than_current_checked :
  Checked.t -> Snark_params.Tick.Boolean.var Snark_params.Tick.Checked.t

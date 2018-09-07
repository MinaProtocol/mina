module Make (Backend : Backend_intf.S) :
  Snark_intf.S
  with type field = Backend.Field.t
   and type Bigint.t = Backend.Bigint.R.t
   and type R1CS_constraint_system.t = Backend.R1CS_constraint_system.t
   and type Var.t = Backend.Var.t
   and type Field.Vector.t = Backend.Field.Vector.t
   and type Verification_key.t = Backend.Verification_key.t
   and type Proving_key.t = Backend.Proving_key.t
   and type Proof.t = Backend.Proof.t

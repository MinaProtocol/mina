open Core
open Snark_params

val input_size : int

val constraint_system : unit -> Tock.R1CS_constraint_system.t

val prove :
     Tick.Verification_key.t
  -> Tock.Proving_key.t
  -> (Tick.Field.t -> Tick.Proof.t -> Tock.Proof.t Or_error.t) Staged.t

val verify :
     Tick.Verification_key.t
  -> Tock.Verification_key.t
  -> (Tick.Field.t -> Tock.Proof.t -> bool) Staged.t

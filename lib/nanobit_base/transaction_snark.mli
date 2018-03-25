open Nanobit_base
open Snark_params

type t

val proof : t -> Tock.Proof.t

val of_transaction
  : Ledger.t
  -> Transaction.t
  -> t

val merge : t -> t -> t

val verify_merge
  : Ledger_hash.var
  -> Ledger_hash.var
  -> (Tock.Proof.t, 's) Tick.As_prover.t
  -> (Tick.Boolean.var, 's) Tick.Checked.t

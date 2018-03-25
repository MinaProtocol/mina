open Snark_params

module Proof_type : sig
  type t = Base | Merge
end

type t

val proof : t -> Tock.Proof.t

val create
  : source:Ledger_hash.t
  -> target:Ledger_hash.t
  -> proof_type:Proof_type.t
  -> proof:Tock.Proof.t
  -> t

val verify : t -> bool

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

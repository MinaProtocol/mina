open Nanobit_base
open Snark_params

type t

val proof : t -> Tock.Proof.t

val of_transaction
  : Ledger.t
  -> Transaction.t
  -> t

val merge : t -> t -> t

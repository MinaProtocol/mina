open Nanobit_base
open Snark_params

type t

val proof : t -> Tock.Proof.t

val of_transaction
  : (Public_key.Compressed.t -> Account.Index.t)
  -> Transaction.t
  -> Ledger.t

val merge : t -> t -> t

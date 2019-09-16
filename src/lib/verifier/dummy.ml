open Async_kernel

type t = unit

type ledger_proof = Ledger_proof.Debug.t

let create _logger = Deferred.return ()

let verify_blockchain_snark _ _ = Deferred.Or_error.return true

let verify_transaction_snark _ _ ~message:_ = Deferred.Or_error.return true

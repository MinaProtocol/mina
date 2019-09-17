open Async_kernel

type t = unit

type ledger_proof = Ledger_proof.Debug.t

let create () = Deferred.return ()

let verify_blockchain_snark _ _ = Deferred.Or_error.return true

let verify_transaction_snark _ proof ~message =
  let msg_digest = Coda_base.Sok_message.digest message in
  Deferred.Or_error.return
    (Coda_base.Sok_message.Digest.equal (snd proof) msg_digest)

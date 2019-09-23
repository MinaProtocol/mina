open Async_kernel
open Coda_base

type t = unit

type ledger_proof = Ledger_proof.Debug.t

let create ~logger:_ ~pids:_ = Deferred.return ()

let verify_blockchain_snark _ _ = Deferred.Or_error.return true

let verify_transaction_snark _ proof ~message =
  (*Don't check if the proof has default sok becasue they were probably not
  intended to be checked. If it has something value then check that against the
  message passed. This is particularly used to test that invalid proofs are not
  added to the snark pool*)
  if Sok_message.Digest.(equal (snd proof) default) then
    Deferred.Or_error.return true
  else
    let msg_digest = Sok_message.digest message in
    Deferred.Or_error.return
      (Coda_base.Sok_message.Digest.equal (snd proof) msg_digest)

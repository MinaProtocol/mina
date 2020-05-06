open Core_kernel
open Async_kernel
open Coda_base

type t = unit

type ledger_proof = Ledger_proof.Debug.t

let create ~logger ~proof_level ~pids:_ ~conf_dir:_ =
  if Genesis_constants.Proof_level.is_compiled proof_level then (
    Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
      "Bad proof level $level (expected $expected)"
      ~metadata:
        [ ( "level"
          , `String (Genesis_constants.Proof_level.to_string proof_level) )
        ; ( "expected"
          , `String Genesis_constants.Proof_level.(to_string compiled) ) ] ;
    Genesis_constants.Proof_level.(
      failwithf "Bad proof level %s (expected %s)" (to_string proof_level)
        (to_string compiled) ()) ) ;
  match proof_level with
  | Genesis_constants.Proof_level.Full ->
      failwith "Unable to handle proof-level=Full"
  | Check | None ->
      Deferred.return ()

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

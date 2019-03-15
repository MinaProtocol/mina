open Core
open Async
open Coda_worker
open Coda_main
open Coda_base
open Signature_lib

let name = "coda-bootstrap-test"

let main () =
  let open Keypair in
  let logger = Logger.create () in
  let largest_account_keypair =
    Genesis_ledger.largest_account_keypair_exn ()
  in
  let n = 2 in
  let proposers i = if i = 0 then Some i else None in
  let snark_work_public_keys i =
    if i = 0 then Some (Public_key.compress largest_account_keypair.public_key)
    else None
  in
  let%bind testnet =
    Coda_worker_testnet.test logger n proposers snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq
  in
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_bootstrap testnet ~logger ~node:1
      ~largest_account_keypair ~payment_receiver:0
  in
  let%bind () = after (Time.Span.of_sec 60.) in
  let%map () = Coda_worker_testnet.Api.teardown testnet in
  Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "SUCCEEDED" ;
  ()

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that triggers bootstrap once"
    (Command.Param.return main)

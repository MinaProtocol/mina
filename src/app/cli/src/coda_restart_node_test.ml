open Core
open Async
open Coda_worker
open Coda_main
open Coda_base
open Signature_lib

let name = "coda-restart-node-test"

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
      ~max_concurrent_connections:(Some 10)
  in
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_catchup testnet ~logger ~node:1
  in
  let%bind () = after (Time.Span.of_sec 180.) in
  Coda_worker_testnet.Api.teardown testnet

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test of stopping, waiting, then starting a node"
    (Command.Param.return main)

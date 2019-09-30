open Core
open Async
open Signature_lib

let name = "coda-restart-node-test"

include Heartbeat.Make ()

let main () =
  let logger = Logger.create () in
  let largest_account_keypair =
    Genesis_ledger.largest_account_keypair_exn ()
  in
  Deferred.don't_wait_for (print_heartbeat logger) ;
  let n = 2 in
  let proposers i = if i = 0 then Some i else None in
  let snark_work_public_keys i =
    if i = 0 then Some (Public_key.compress largest_account_keypair.public_key)
    else None
  in
  let%bind testnet =
    Coda_worker_testnet.test logger n proposers snark_work_public_keys
      Cli_lib.Arg_type.Sequence ~max_concurrent_connections:None
  in
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_catchup testnet ~logger ~node:1
  in
  let%bind () = after (Time.Span.of_min 2.) in
  heartbeat_flag := false ;
  Coda_worker_testnet.Api.teardown testnet

let command =
  Command.async ~summary:"Test of stopping, waiting, then starting a node"
    (Command.Param.return main)

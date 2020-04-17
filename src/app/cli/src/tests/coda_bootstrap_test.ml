open Core
open Async
open Signature_lib

let name = "coda-bootstrap-test"

let main () =
  let logger = Logger.create () in
  let largest_account_keypair =
    Test_genesis_ledger.largest_account_keypair_exn ()
  in
  let n = 2 in
  let block_production_keys i = Some i in
  let snark_work_public_keys i =
    if i = 0 then Some (Public_key.compress largest_account_keypair.public_key)
    else None
  in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n block_production_keys
      snark_work_public_keys Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None
  in
  let previous_status = Sync_status.Table.create () in
  let bootstrapping_node = 1 in
  (let%bind sync_status_pipe_opt =
     Coda_worker_testnet.Api.sync_status testnet bootstrapping_node
   in
   Pipe_lib.Linear_pipe.iter (Option.value_exn sync_status_pipe_opt)
     ~f:(fun sync_status ->
       Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
         ~metadata:[("status", Sync_status.to_yojson sync_status)]
         "Bootstrap node received status: $status" ;
       Sync_status.Table.update previous_status sync_status
         ~f:(Option.value_map ~default:1 ~f:(( + ) 1)) ;
       Deferred.unit ))
  |> don't_wait_for ;
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_bootstrap testnet ~logger
      ~node:bootstrapping_node
  in
  let%bind () =
    let constants = Consensus.Constants.compiled in
    let root_transition_time i =
      ( Block_time.Span.to_ms constants.block_window_duration_ms
      |> Int64.to_int_exn )
      * Unsigned.UInt32.to_int constants.k
      * i
      |> Float.of_int
    in
    (*Wait till the root transitions once *)
    Async.after (Core.Time.Span.of_ms (root_transition_time 1))
  in
  (*bootstrap again*)
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_bootstrap testnet ~logger
      ~node:bootstrapping_node
  in
  let%bind () = after (Time.Span.of_sec 180.) in
  let bootstrap_count =
    Sync_status.Table.find_exn previous_status `Bootstrap
  in
  let synced_count = Sync_status.Table.find_exn previous_status `Synced in
  (*Statuses change when the node first starts and when bootstrap is triggered twice*)
  assert (bootstrap_count >= 3 && synced_count >= 3) ;
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  Command.async ~summary:"Test that triggers bootstrap once"
    (Command.Param.return main)

open Core
open Async
open Signature_lib

let name = "coda-restart-node-test"

include Heartbeat.Make ()

let main ~runtime_config () =
  let logger = Logger.create () in
  let%bind {Precomputed_values.genesis_ledger; base_proof; runtime_config; _} =
    Deferred.Or_error.ok_exn
    @@ Precomputed_values.load_values ~logger ~not_found:`Generate_and_store
         ~runtime_config ()
  in
  let (module Genesis_ledger : Genesis_ledger.Intf.S) = genesis_ledger in
  let largest_account_keypair =
    Genesis_ledger.largest_account_keypair_exn ()
  in
  Deferred.don't_wait_for (print_heartbeat logger) ;
  let n = 2 in
  let block_production_keys i = if i = 0 then Some i else None in
  let snark_work_public_keys i =
    if i = 0 then Some (Public_key.compress largest_account_keypair.public_key)
    else None
  in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n block_production_keys
      snark_work_public_keys Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~runtime_config ~base_proof
  in
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_catchup testnet ~logger ~node:1
  in
  let%bind () = after (Time.Span.of_min 2.) in
  heartbeat_flag := false ;
  Coda_worker_testnet.Api.teardown testnet ~logger

(* TODO: Test-specific runtime config. *)
let default_runtime_config = Runtime_config.compile_config

let command =
  Command.async ~summary:"Test of stopping, waiting, then starting a node"
    (let open Command.Let_syntax in
    let%map runtime_config =
      Runtime_config.from_flags default_runtime_config
    in
    main ~runtime_config)

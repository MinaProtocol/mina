open Core
open Async
open Signature_lib

let name = "coda-bootstrap-test"

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
  let n = 2 in
  let block_production_keys i = Some i in
  let snark_work_public_keys i =
    if i = 0 then Some (Public_key.compress largest_account_keypair.public_key)
    else None
  in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n block_production_keys
      snark_work_public_keys Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~runtime_config ~base_proof
  in
  let previous_status = Sync_status.Hash_set.create () in
  let bootstrapping_node = 1 in
  (let%bind sync_status_pipe_opt =
     Coda_worker_testnet.Api.sync_status testnet bootstrapping_node
   in
   Pipe_lib.Linear_pipe.iter (Option.value_exn sync_status_pipe_opt)
     ~f:(fun sync_status ->
       Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
         ~metadata:[("status", Sync_status.to_yojson sync_status)]
         "Bootstrap node received status: $status" ;
       Hash_set.add previous_status sync_status ;
       Deferred.unit ))
  |> don't_wait_for ;
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_bootstrap testnet ~logger
      ~node:bootstrapping_node
  in
  let%bind () = after (Time.Span.of_sec 180.) in
  (* TODO: one of the previous_statuses should be `Bootstrap. The broadcast pip 
    coda.transition_frontier never gets set to None *)
  assert (Hash_set.mem previous_status `Synced) ;
  Coda_worker_testnet.Api.teardown testnet ~logger

(* TODO: Test-specific runtime config. *)
let default_runtime_config = Runtime_config.compile_config

let command =
  Command.async ~summary:"Test that triggers bootstrap once"
    (let open Command.Let_syntax in
    let%map runtime_config =
      Runtime_config.from_flags default_runtime_config
    in
    main ~runtime_config)

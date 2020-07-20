open Core
open Async

let name = "coda-bootstrap-test"

let runtime_config =
  lazy
    ( (* test_postake_bootstrap *)
      {json|
  { "daemon":
      { "txpool_max_size": 3000 }
  , "genesis":
      { "k": 6
      , "delta": 3
      , "genesis_state_timestamp": "2019-01-30 12:00:00-08:00" }
  , "proof":
      { "level": "none"
      , "c": 8
      , "ledger_depth": 6
      , "work_delay": 2
      , "block_window_duration_ms": 1500
      , "transaction_capacity": {"2_to_the": 3}
      , "coinbase_amount": "20"
      , "account_creation_fee": "1" }
  , "ledger": { "name": "test", "add_genesis_winner": false } }
      |json}
    |> Yojson.Safe.from_string |> Runtime_config.of_yojson
    |> Result.ok_or_failwith )

let main () =
  let logger = Logger.create () in
  let%bind precomputed_values, _runtime_config =
    Genesis_ledger_helper.init_from_config_file ~logger ~may_generate:false
      ~proof_level:None
      (Lazy.force runtime_config)
    >>| Or_error.ok_exn
  in
  let n = 2 in
  let block_production_keys i = Some i in
  let snark_work_public_keys i =
    if i = 0 then
      Some (Precomputed_values.largest_account_pk_exn precomputed_values)
    else None
  in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n block_production_keys
      snark_work_public_keys Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~precomputed_values
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
  (* TODO: one of the previous_statuses should be `Bootstrap. The broadcast pip
    coda.transition_frontier never gets set to None *)
  assert (Hash_set.mem previous_status `Synced) ;
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  Command.async ~summary:"Test that triggers bootstrap once"
    (Command.Param.return main)

open Core
open Async

let name = "coda-long-fork"

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
  , "ledger": { "name": "test" } }
      |json}
    |> Yojson.Safe.from_string |> Runtime_config.of_yojson
    |> Result.ok_or_failwith )

let main n waiting_time () =
  let logger = Logger.create () in
  let%bind precomputed_values, runtime_config =
    Genesis_ledger_helper.init_from_config_file ~logger ~may_generate:false
      ~proof_level:None
      (Lazy.force runtime_config)
    >>| Or_error.ok_exn
  in
  let consensus_constants = precomputed_values.consensus_constants in
  let public_keys =
    List.map
      (Lazy.force (Precomputed_values.accounts precomputed_values))
      ~f:Precomputed_values.pk_of_account_record
  in
  let snark_work_public_keys i = Some (List.nth_exn public_keys i) in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n Option.some snark_work_public_keys
      Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~runtime_config
  in
  let epoch_duration =
    let block_window_duration_ms =
      Block_time.Span.to_ms consensus_constants.block_window_duration_ms
      |> Int64.to_int_exn
    in
    Unsigned.UInt32.(
      block_window_duration_ms * 3
      * to_int consensus_constants.c
      * to_int consensus_constants.k)
  in
  let%bind () =
    Coda_worker_testnet.Restarts.restart_node testnet ~logger ~node:1
      ~duration:(Time.Span.of_ms (2 * epoch_duration |> Float.of_int))
  in
  let%bind () = after (Time.Span.of_sec (waiting_time |> Float.of_int)) in
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that one worker goes offline for a long time"
    (let%map_open num_block_producers =
       flag "num-block-producers" ~doc:"NUM number of block producers to have"
         (required int)
     and waiting_time =
       flag "waiting-time"
         ~doc:"the waiting time after the nodes coming back alive"
         (optional_with_default 120 int)
     in
     main num_block_producers waiting_time)

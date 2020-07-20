open Core
open Async

let name = "coda-shared-prefix-test"

let runtime_config =
  lazy
    ( (* test_postake_split_snarkless *)
      {json|
  { "daemon":
      { "txpool_max_size": 3000 }
  , "genesis":
      { "k": 24
      , "delta": 3
      , "genesis_state_timestamp": "2019-01-30 12:00:00-08:00" }
  , "proof":
      { "level": "check"
      , "c": 8
      , "ledger_depth": 30
      , "work_delay": 1
      , "block_window_duration_ms": 10000
      , "transaction_capacity": {"2_to_the": 2}
      , "coinbase_amount": "20"
      , "account_creation_fee": "1" }
  , "ledger":
      { "name": "test_split_two_stakers"
      , "add_genesis_winner": false } }
      |json}
    |> Yojson.Safe.from_string |> Runtime_config.of_yojson
    |> Result.ok_or_failwith )

let main who_produces () =
  let logger = Logger.create () in
  let%bind precomputed_values, _runtime_config =
    Genesis_ledger_helper.init_from_config_file ~logger ~may_generate:false
      ~proof_level:None
      (Lazy.force runtime_config)
    >>| Or_error.ok_exn
  in
  let n = 2 in
  let block_producers i = if i = who_produces then Some i else None in
  let snark_work_public_keys _ = None in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n block_producers
      snark_work_public_keys Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~precomputed_values
  in
  let%bind () = after (Time.Span.of_sec 60.) in
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that workers share prefixes"
    (let%map_open who_produces =
       flag "who-produces" ~doc:"ID node number which will be producing blocks"
         (required int)
     in
     main who_produces)

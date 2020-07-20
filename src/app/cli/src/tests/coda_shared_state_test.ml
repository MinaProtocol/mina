open Core
open Async

let name = "coda-shared-state-test"

let runtime_config =
  lazy
    ( (* test_postake_txns *)
      {json|
  { "daemon":
      { "txpool_max_size": 3000 }
  , "genesis":
      { "k": 6
      , "delta": 3
      , "genesis_state_timestamp": "2019-01-30 12:00:00-08:00" }
  , "proof":
      { "level": "check"
      , "c": 8
      , "ledger_depth": 6
      , "work_delay": 2
      , "block_window_duration_ms": 15000
      , "transaction_capacity": {"2_to_the": 3}
      , "coinbase_amount": "20"
      , "account_creation_fee": "1" }
  , "ledger":
      { "name": "test_split_two_stakers"
      , "add_genesis_winner": false } }
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
  let keypairs =
    List.map
      (Lazy.force (Precomputed_values.accounts precomputed_values))
      ~f:Precomputed_values.keypair_of_account_record_exn
  in
  let public_keys =
    List.map ~f:Precomputed_values.pk_of_account_record
      (Lazy.force (Precomputed_values.accounts precomputed_values))
  in
  let snark_work_public_keys i = Some (List.nth_exn public_keys i) in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n Option.some snark_work_public_keys
      Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None
      ~runtime_config:
        (Genesis_ledger_helper.extract_runtime_config precomputed_values)
  in
  let%bind () =
    Coda_worker_testnet.Payments.send_several_payments testnet ~node:0
      ~keypairs ~n:3
  in
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  Command.async ~summary:"Test that workers share states"
    (Command.Param.return main)

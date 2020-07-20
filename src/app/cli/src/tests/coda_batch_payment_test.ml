open Core
open Async
open Signature_lib

let name = "coda-batch-payment-test"

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
  Core.Backtrace.elide := false ;
  Async.Scheduler.set_record_backtraces true ;
  let logger = Logger.create () in
  let%bind precomputed_values, _runtime_config =
    Genesis_ledger_helper.init_from_config_file ~logger ~may_generate:false
      ~proof_level:None
      (Lazy.force runtime_config)
    >>| Or_error.ok_exn
  in
  let (module Genesis_ledger) = precomputed_values.genesis_ledger in
  let keypairs =
    List.map
      (Lazy.force Genesis_ledger.accounts)
      ~f:Genesis_ledger.keypair_of_account_record_exn
  in
  let largest_account_keypair =
    Genesis_ledger.largest_account_keypair_exn ()
  in
  let block_production_keys i = if i = 0 then Some i else None in
  let snark_work_public_keys i =
    if i = 0 then Some (Public_key.compress largest_account_keypair.public_key)
    else None
  in
  let num_nodes = 3 in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger num_nodes block_production_keys
      snark_work_public_keys Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None
      ~runtime_config:
        (Genesis_ledger_helper.extract_runtime_config precomputed_values)
  in
  let%bind payments =
    Coda_worker_testnet.Payments.send_batch_consecutive_payments testnet
      ~node:0 ~keypairs ~sender:largest_account_keypair.private_key ~n:4
  in
  let%bind () =
    Coda_worker_testnet.Payments.assert_retrievable_payments testnet payments
  in
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  Command.async ~summary:"Test batch payments" (Async.Command.Spec.return main)

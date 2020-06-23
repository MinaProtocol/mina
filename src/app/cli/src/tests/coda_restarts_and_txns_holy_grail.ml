open Core
open Async
open Coda_base

let name = "coda-restarts-and-txns-holy-grail"

let runtime_config =
  lazy
    ( (* test_postake_holy_grail *)
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
      , "block_window_duration_ms": 2000
      , "transaction_capacity": {"2_to_the": 3}
      , "coinbase_amount": "20"
      , "account_creation_fee": "1" }
  , "ledger": { "name": "test_five_even_stakes" } }
      |json}
    |> Yojson.Safe.from_string |> Runtime_config.of_yojson
    |> Result.ok_or_failwith )

let main n () =
  let wait_time = Time.Span.of_min 2. in
  assert (n > 1) ;
  let logger = Logger.create () in
  let%bind precomputed_values, runtime_config =
    Genesis_ledger_helper.init_from_config_file ~logger ~may_generate:false
      ~proof_level:None
      (Lazy.force runtime_config)
    >>| Or_error.ok_exn
  in
  let accounts = Lazy.force (Precomputed_values.accounts precomputed_values) in
  let snark_work_public_keys =
    Fn.const @@ Some (List.nth_exn accounts 5 |> snd |> Account.public_key)
  in
  let block_production_keys n = if n < 3 then Some n else None in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n block_production_keys
      snark_work_public_keys Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~runtime_config
  in
  (* SEND TXNS *)
  let keypairs =
    List.map accounts ~f:Precomputed_values.keypair_of_account_record_exn
  in
  let random_block_producer () = Random.int 2 + 1 in
  let random_non_block_producer () = Random.int 2 + 3 in
  Coda_worker_testnet.Payments.send_several_payments testnet ~node:0 ~keypairs
    ~n:10
  |> don't_wait_for ;
  (* RESTART NODES *)
  (* catchup *)
  let%bind () = after wait_time in
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_catchup testnet ~logger
      ~node:(random_non_block_producer ())
  in
  let%bind () = after wait_time in
  (* bootstrap *)
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_bootstrap testnet ~logger
      ~node:(random_non_block_producer ())
  in
  (* random restart *)
  let%bind () = after wait_time in
  let%bind () =
    Coda_worker_testnet.Restarts.restart_node testnet ~logger
      ~node:(random_block_producer ())
      ~duration:(Time.Span.of_min (Random.float 3.))
  in
  (* settle for a few more min *)
  let%bind () = after wait_time in
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  let open Command.Let_syntax in
  Command.async
    ~summary:
      "Test the holy grail for n nodes: All sorts of restarts and \
       transactions work"
    (let%map_open num_block_producers =
       flag "num-block-producers" ~doc:"NUM number of block producers to have"
         (required int)
     in
     main num_block_producers)

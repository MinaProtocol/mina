open Core
open Async
open Coda_base

let name = "coda-txns-and-restart-non-producers"

let runtime_config = Runtime_config.Test_configs.three_producers

let main () =
  let wait_time = Time.Span.of_min 2. in
  let logger = Logger.create () in
  let%bind precomputed_values, _runtime_config =
    Genesis_ledger_helper.init_from_config_file ~logger ~may_generate:false
      ~proof_level:None
      (Lazy.force runtime_config)
    >>| Or_error.ok_exn
  in
  let accounts = Lazy.force (Precomputed_values.accounts precomputed_values) in
  let snark_work_public_keys =
    Fn.const @@ Some (List.nth_exn accounts 5 |> snd |> Account.public_key)
  in
  let producers n = if n < 3 then Some n else None in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger 5 producers snark_work_public_keys
      Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~precomputed_values
  in
  (* send txns *)
  let keypairs =
    List.map accounts ~f:Precomputed_values.keypair_of_account_record_exn
  in
  let%bind () = after wait_time in
  Coda_worker_testnet.Payments.send_several_payments testnet ~node:0 ~keypairs
    ~n:10
  |> don't_wait_for ;
  (* restart non-producers *)
  let random_non_producer () = Random.int 2 + 3 in
  (* catchup *)
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_catchup testnet ~logger
      ~node:(random_non_producer ())
  in
  let%bind () = after wait_time in
  (* bootstrap *)
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_bootstrap testnet ~logger
      ~node:(random_non_producer ())
  in
  (* random restart *)
  let%bind () = after wait_time in
  let%bind () =
    Coda_worker_testnet.Restarts.restart_node testnet ~logger
      ~node:(random_non_producer ())
      ~duration:(Time.Span.of_min (Random.float 3. +. 1.))
  in
  (* settle for a few more min *)
  let%bind () = after wait_time in
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  Command.async ~summary:"only restart non-block-producers"
    (Command.Param.return main)

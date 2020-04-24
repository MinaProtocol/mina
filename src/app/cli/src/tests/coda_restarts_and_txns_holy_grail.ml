open Core
open Async
open Coda_base

let name = "coda-restarts-and-txns-holy-grail"

let main ~runtime_config n () =
  let logger = Logger.create () in
  let%bind {Precomputed_values.genesis_ledger; base_proof; runtime_config; _} =
    Deferred.Or_error.ok_exn
    @@ Precomputed_values.load_values ~logger ~not_found:`Generate_and_store
         ~runtime_config ()
  in
  let (module Genesis_ledger : Genesis_ledger.Intf.S) = genesis_ledger in
  let wait_time = Time.Span.of_min 2. in
  assert (n > 1) ;
  let accounts = Lazy.force Genesis_ledger.accounts in
  let snark_work_public_keys =
    Fn.const @@ Some (List.nth_exn accounts 5 |> snd |> Account.public_key)
  in
  let block_production_keys n = if n < 3 then Some n else None in
  let%bind testnet =
    Coda_worker_testnet.test ~name logger n block_production_keys
      snark_work_public_keys Cli_lib.Arg_type.Work_selection_method.Sequence
      ~max_concurrent_connections:None ~runtime_config ~base_proof
  in
  (* SEND TXNS *)
  let keypairs =
    List.map accounts ~f:Genesis_ledger.keypair_of_account_record_exn
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

(* TODO: Test-specific runtime config. *)
let default_runtime_config = Runtime_config.compile_config

let command =
  let open Command.Let_syntax in
  Command.async
    ~summary:
      "Test the holy grail for n nodes: All sorts of restarts and \
       transactions work"
    (let%map_open num_block_producers =
       flag "num-block-producers" ~doc:"NUM number of block producers to have"
         (required int)
     and runtime_config = Runtime_config.from_flags default_runtime_config in
     main ~runtime_config num_block_producers)

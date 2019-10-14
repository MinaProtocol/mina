open Core
open Async
open Coda_base

let name = "coda-txns-and-restart-non-proposers"

let main () =
  let logger = Logger.create () in
  let snark_work_public_keys =
    Fn.const
    @@ Some
         (List.nth_exn Genesis_ledger.accounts 5 |> snd |> Account.public_key)
  in
  let proposers n = if n < 3 then Some n else None in
  let%bind testnet =
    Coda_worker_testnet.test logger 5 proposers snark_work_public_keys
      Cli_lib.Arg_type.Sequence ~max_concurrent_connections:None
  in
  (* send txns *)
  let keypairs =
    List.map Genesis_ledger.accounts
      ~f:Genesis_ledger.keypair_of_account_record_exn
  in
  Coda_worker_testnet.Payments.send_several_payments testnet ~node:0 ~keypairs
    ~n:10
  |> don't_wait_for ;
  (* restart non-proposers *)
  let random_non_proposer () = Random.int 2 + 3 in
  (* catchup *)
  let%bind () = after (Time.Span.of_sec 30.) in
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_catchup testnet ~logger
      ~node:(random_non_proposer ())
  in
  let%bind () = after (Time.Span.of_min 1.) in
  (* bootstrap *)
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_bootstrap testnet ~logger
      ~node:(random_non_proposer ())
  in
  (* random restart *)
  let%bind () = after (Time.Span.of_min 1.) in
  let%bind () =
    Coda_worker_testnet.Restarts.restart_node testnet ~logger
      ~node:(random_non_proposer ())
      ~duration:(Time.Span.of_min (Random.float 3. +. 1.))
  in
  (* settle for a few more min *)
  let%bind () = after (Time.Span.of_min 1.) in
  Coda_worker_testnet.Api.teardown testnet ~logger

let command =
  Command.async ~summary:"only restart non-proposers"
    (Command.Param.return main)

open Core
open Async
open Coda_worker
open Coda_main
open Coda_base

let name = "coda-restarts-and-txns-holy-grail"

let main n () =
  assert (n > 1) ;
  let logger = Logger.create () in
  let snark_work_public_keys =
    Fn.const
    @@ Some
         (List.nth_exn Genesis_ledger.accounts 5 |> snd |> Account.public_key)
  in
  let%bind testnet =
    Coda_worker_testnet.test logger n Option.some snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq ~max_concurrent_connections:None
  in
  (* SEND TXNS *)
  let keypairs =
    List.map Genesis_ledger.accounts
      ~f:Genesis_ledger.keypair_of_account_record_exn
  in
  Coda_worker_testnet.Payments.send_several_payments testnet ~node:0 ~keypairs
    ~n:25
  |> don't_wait_for ;
  (* RESTART NODES *)
  (* catchup *)
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_catchup testnet ~logger ~node:2
  in
  let%bind () = after (Time.Span.of_min 1.) in
  (* bootstrap *)
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_bootstrap testnet ~logger ~node:1
  in
  (* TODO: We should add the random restart again once the Genesis Ledger is
     implemented. *)
  (* settle for a few more min *)
  (* TODO: Make sure to check that catchup actually worked *)
  let%bind () = after (Time.Span.of_min 4.) in
  Coda_worker_testnet.Api.teardown testnet

let command =
  let open Command.Let_syntax in
  Command.async
    ~summary:
      "Test the holy grail for n nodes: All sorts of restarts and \
       transactions work"
    (let%map_open num_proposers =
       flag "num-proposers" ~doc:"NUM number of proposers to have"
         (required int)
     in
     main num_proposers)

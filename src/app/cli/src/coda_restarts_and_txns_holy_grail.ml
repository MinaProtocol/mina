open Core
open Async
open Coda_worker
open Coda_main
open Coda_base

let name = "coda-restarts-and-txns-holy-grail"

let main n () =
  assert (n > 1) ;
  let logger = Logger.create () in
  let snark_work_public_keys = function
    | 0 ->
        Some
          (List.nth_exn Genesis_ledger.accounts 5 |> snd |> Account.public_key)
    | _ -> None
  in
  let%bind testnet =
    Coda_worker_testnet.test logger n Option.some snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq
  in
  (* SEND TXNS *)
  let keypairs =
    List.map Genesis_ledger.accounts
      ~f:Genesis_ledger.keypair_of_account_record_exn
  in
  Coda_worker_testnet.Payments.send_several_payments testnet ~node:0 ~keypairs
    ~n:3
  |> don't_wait_for ;
  (* RESTART NODES *)
  (* catchup *)
  let idx = Quickcheck.random_value (Int.gen_incl 1 (n - 1)) in
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_catchup testnet ~logger ~node:idx
  in
  (* bootstrap *)
  let idx = Quickcheck.random_value (Int.gen_incl 1 (n - 1)) in
  let%bind () =
    Coda_worker_testnet.Restarts.trigger_bootstrap testnet ~logger ~node:idx
  in
  (* random *)
  let idx = Quickcheck.random_value (Int.gen_incl 1 (n - 1)) in
  let duration =
    Quickcheck.(
      random_value
        Generator.(Float.gen_incl 1. 5. >>| fun x -> Time.Span.of_min x))
  in
  let%bind () =
    Coda_worker_testnet.Restarts.restart_node testnet ~logger ~node:idx
      ~duration
  in
  (* settle for a few more min *)
  (* TODO: Make sure to check that catchup actually worked *)
  let%bind () = after (Time.Span.of_min 3.) in
  Coda_worker_testnet.Api.teardown testnet

let command =
  let open Command.Let_syntax in
  Command.async
    ~summary:
      "Test the holy grail for n nodes: All sorts of restarts and \
       transactions work"
    (let%map_open who_proposes =
       flag "who-proposes" ~doc:"ID node number which will be proposing"
         (required int)
     in
     main who_proposes)

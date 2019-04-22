open Core
open Async
open Coda_worker
open Coda_main
open Coda_base

let name = "coda-long-fork"

let main n () =
  let logger = Logger.create () in
  let keypairs =
    List.map Genesis_ledger.accounts
      ~f:Genesis_ledger.keypair_of_account_record_exn
  in
  let snark_work_public_keys i =
    Some
      ( (List.nth_exn keypairs i).public_key
      |> Signature_lib.Public_key.compress )
  in
  let%bind testnet =
    Coda_worker_testnet.test logger n Option.some snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq ~max_concurrent_connections:None
  in
  let epoche_duration =
    Consensus.Constants.(block_window_duration_ms * 3 * c * k)
  in
  let%bind () =
    Coda_worker_testnet.Restarts.restart_node testnet ~logger ~node:1
      ~duration:(Time.Span.of_ms (3 * epoche_duration |> Float.of_int))
  in
  let%bind () = after (Time.Span.of_min 2.) in
  Coda_worker_testnet.Api.teardown testnet

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that workers share prefixes"
    (let%map_open num_proposers =
       flag "num-proposers" ~doc:"NUM number of proposers to have"
         (required int)
     in
     main num_proposers)

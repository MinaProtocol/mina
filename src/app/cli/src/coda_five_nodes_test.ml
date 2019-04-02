open Core
open Async
open Coda_worker
open Coda_main
open Coda_base

let name = "coda-five-nodes-test"

let main () =
  let logger = Logger.create () in
  let n = 5 in
  let snark_work_public_keys = function
    | 0 ->
        Some
          (List.nth_exn Genesis_ledger.accounts 5 |> snd |> Account.public_key)
    | _ -> None
  in
  let%bind testnet =
    Coda_worker_testnet.test logger n Option.some snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq
      ~max_concurrent_connections:(Some 10)
  in
  let%bind () = after (Time.Span.of_min 10.) in
  Coda_worker_testnet.Api.teardown testnet

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that five nodes work"
    (Command.Param.return main)

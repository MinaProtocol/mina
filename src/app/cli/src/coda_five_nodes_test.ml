open Core
open Async
open Coda_worker
open Coda_main
open Coda_base

let name = "coda-five-nodes-test"

let main () =
  let log = Logger.create () in
  let log = Logger.child log name in
  let n = 6 in
  let snark_work_public_keys = function
    | 0 ->
        Some
          (List.nth_exn Genesis_ledger.accounts 5 |> snd |> Account.public_key)
    | _ -> None
  in
  let%bind testnet =
    Coda_worker_testnet.test log n
      (fun i -> if i < 5 then Some i else None)
      snark_work_public_keys Protocols.Coda_pow.Work_selection.Seq
  in
  after (Time.Span.of_min 45.)

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that five nodes work"
    (Command.Param.return main)

open Core
open Async
open Coda_worker
open Coda_main

let name = "coda-shared-prefix-multiproposer-test"

let main () =
  let log = Logger.create () in
  let log = Logger.child log name in
  let n = 2 in
  let snark_work_public_keys i = None in
  let%bind testnet =
    Coda_worker_testnet.test log n Option.some snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq
  in
  let%bind () = after (Time.Span.of_sec 30.) in
  Coda_worker_testnet.Api.teardown testnet

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that workers share prefixes"
    (Command.Param.return main)

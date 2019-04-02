open Core
open Async
open Coda_worker
open Coda_main

let name = "coda-block-production-test"

let main () =
  let logger = Logger.create () in
  let n = 1 in
  let snark_work_public_keys i = None in
  let%bind testnet =
    Coda_worker_testnet.test logger n Option.some snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq
      ~max_concurrent_connections:(Some 10)
  in
  let%bind () = after (Time.Span.of_sec 30.) in
  Coda_worker_testnet.Api.teardown testnet

let command =
  Command.async ~summary:"Test that blocks get produced"
    (Command.Param.return main)

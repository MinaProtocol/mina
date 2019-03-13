open Core
open Async
open Coda_worker
open Coda_main

let name = "coda-shared-prefix-multiproposer-test"

let main n () =
  let logger = Logger.create () in
  let snark_work_public_keys i = None in
  let%bind testnet =
    Coda_worker_testnet.test logger n Option.some snark_work_public_keys
      Protocols.Coda_pow.Work_selection.Seq
  in
  let%bind () = after (Time.Span.of_min 3.) in
  Coda_worker_testnet.Api.teardown testnet

let command =
  let open Command.Let_syntax in
  Command.async ~summary:"Test that workers share prefixes"
    (let%map_open num_proposers =
       flag "num-proposers" ~doc:"NUM number of proposers to have"
         (required int)
     in
     main num_proposers)

open Core
open Async
open Coda_worker
open Coda_main

module Make (Kernel : Kernel_intf) : Integration_test_intf.S = struct
  module Coda_processes = Coda_processes.Make (Kernel)
  open Coda_processes
  module Coda_worker_testnet = Coda_worker_testnet.Make (Kernel)

  let name = "coda-shared-prefix-test"

  let main who_proposes proposal_interval () =
    let log = Logger.create () in
    let log = Logger.child log name in
    let n = 2 in
    let should_propose i = i = who_proposes in
    let snark_work_public_keys i = None in
    let%bind testnet =
      Coda_worker_testnet.test log n ?proposal_interval should_propose
        snark_work_public_keys Protocols.Coda_pow.Work_selection.Seq
    in
    after (Time.Span.of_sec 30.)

  let command =
    let open Command.Let_syntax in
    Command.async ~summary:"Test that workers share prefixes"
      (let%map_open who_proposes =
         flag "who-proposes" ~doc:"ID node number which will be proposing"
           (required int)
       and proposal_interval =
         flag "proposal-interval"
           ~doc:"MILLIS proposal interval in proof of sig" (optional int)
       in
       main who_proposes proposal_interval)
end

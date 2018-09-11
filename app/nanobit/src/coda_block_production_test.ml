open Core
open Async
open Coda_worker
open Coda_main

module Make
    (Ledger_proof : Ledger_proof_intf)
    (Kernel : Kernel_intf with type Ledger_proof.t = Ledger_proof.t)
    (Coda : Coda_intf.S with type ledger_proof = Ledger_proof.t) :
  Integration_test_intf.S =
struct
  module Coda_processes = Coda_processes.Make (Ledger_proof) (Kernel) (Coda)
  open Coda_processes

  module Coda_worker_testnet = Coda_worker_testnet.Make (Ledger_proof) (Kernel) (Coda)

  let name = "coda-block-production-test"

  let main () =
    let log = Logger.create () in
    let log = Logger.child log name in
    let n = 1 in
    let should_propose = fun i -> true in
    let snark_work_public_keys = fun i -> None in
    let%bind (api, finished) = 
      Coda_worker_testnet.test log n should_propose snark_work_public_keys
    in
    Logger.fatal log "before";
    let%bind () = after (Time.Span.of_sec 30.) in
    Logger.fatal log "after";
    finished

  let command =
    Command.async_spec ~summary:"Simple use of Async Rpc_parallel V2"
      Command.Spec.(empty)
      main
end

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
  module Coda_worker_testnet =
    Coda_worker_testnet.Make (Ledger_proof) (Kernel) (Coda)

  let name = "coda-restart-node-test"

  let main () =
    let%bind program_dir = Unix.getcwd () in
    let log = Logger.create () in
    let log = Logger.child log name in
    Coda_processes.init () ;
    let n = 1 in
    Logger.info log "A" ;
    let configs =
      Coda_processes.local_configs n ~program_dir
        ~snark_worker_public_keys:None ~should_propose:(Fn.const false)
    in
    let%bind workers = Coda_processes.spawn_local_processes_exn configs in
    let worker = List.hd_exn workers in
    Logger.info log "B" ;
    let%map () = Coda_process.disconnect worker in
    Logger.info log "C" ; ()

  let command =
    Command.async_spec ~summary:"Simple use of Async Rpc_parallel V2"
      Command.Spec.(empty)
      main
end

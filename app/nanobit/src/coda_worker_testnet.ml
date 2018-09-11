open Core
open Async
open Coda_worker
open Coda_main

module Make
    (Ledger_proof : Ledger_proof_intf)
    (Kernel : Kernel_intf with type Ledger_proof.t = Ledger_proof.t)
    (Coda : Coda_intf.S with type ledger_proof = Ledger_proof.t) =
struct
  module Coda_processes = Coda_processes.Make (Ledger_proof) (Kernel) (Coda)
  open Coda_processes

  let test log n =
    let%bind program_dir = Unix.getcwd () in
    Coda_processes.init () ;
    Coda_processes.spawn_local_processes_exn n ~program_dir
      ~should_propose:(fun i -> false)
      ~snark_worker_public_keys:None
      ~f:(fun workers ->
        return () )
end


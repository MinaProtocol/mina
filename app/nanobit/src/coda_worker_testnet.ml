open Core
open Async
open Coda_worker
open Coda_main
open Signature_lib

module Make
    (Ledger_proof : Ledger_proof_intf)
    (Kernel : Kernel_intf with type Ledger_proof.t = Ledger_proof.t)
    (Coda : Coda_intf.S with type ledger_proof = Ledger_proof.t) =
struct
  module Coda_processes = Coda_processes.Make (Ledger_proof) (Kernel) (Coda)
  open Coda_processes

  type api = 
    { stop: int -> unit
    ; start: int -> unit
    ; send_transaction: int 
        -> Private_key.t
      -> Public_key.Compressed.t
      -> Currency.Amount.t
      -> Currency.Fee.t -> unit Deferred.t
    }

  (* step 1:
   * step 2:
   *   change live whether nodes are producing, snark producing
   *   change network connectivity *)
  let test 
      log 
      n 
      should_propose 
      snark_work_public_keys 
    =
    let ready = 
      Deferred.create (fun ready_ivar -> 
          let fill_ready = ref None in
          let finished = 
            Deferred.create (fun finished_ivar -> 
                don't_wait_for begin
                  let%bind program_dir = Unix.getcwd () in
                  Coda_processes.init () ;
                  let%map () = Coda_processes.spawn_local_processes_exn n ~program_dir
                      ~should_propose
                      ~snark_worker_public_keys:(Some (List.init n snark_work_public_keys))
                      ~f:(fun workers ->
                          Option.value_exn !fill_ready workers;
                          return () ) in
                  Ivar.fill finished_ivar ()
                end
              ) in
          fill_ready := Some (fun workers -> 
              let api = 
                { stop = (fun i -> failwith "nyi")
                ; start = (fun i -> failwith "nyi")
                ; send_transaction = (fun i sk pk amount fee -> Coda_process.send_transaction_exn (List.nth_exn workers i) sk pk amount fee)
                } 
              in
              Ivar.fill ready_ivar (api, finished)
            )
        ) in
    ready
end


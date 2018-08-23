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

  let name = "coda-shared-prefix-test"
  let main () =
    Coda_processes.init () ;
    let%bind program_dir = Unix.getcwd () in
    let n = 2 in
    let log = Logger.create () in
    let log = Logger.child log name in
    Coda_processes.init () ;
    Coda_processes.spawn_local_processes_exn n ~program_dir ~f:(fun workers ->
        let%bind () = 
          Deferred.List.all_unit begin
            List.mapi workers
              ~f:(fun i worker -> 
                  let%bind strongest_ledgers = Coda_process.strongest_ledgers_exn worker in
                  don't_wait_for begin
                    Linear_pipe.iter strongest_ledgers
                      ~f:(fun l -> 
                          Logger.info log "got ledger %d" i;
                          return ())
                  end;
                  Deferred.unit
                )
          end
        in
        let%bind () = after (Time.Span.of_sec 1000000.) in
        return ()
      )

  let command =
    Command.async_spec ~summary:"Simple use of Async Rpc_parallel V2"
      Command.Spec.(empty)
      main

end

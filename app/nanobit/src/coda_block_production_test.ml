open Core
open Async
open Coda_worker
open Coda_processes

let main () =
  Coda_processes.init () ;
  let gossip_port = 8000 in
  let port = 3000 in
  let peers = [] in
  let%bind program_dir = Unix.getcwd () in
  Coda_process.spawn_local_exn ~peers ~port ~gossip_port ~program_dir
    ~f:(fun worker ->
      let%bind res = Coda_process.sum_exn worker 40 in
      let%bind peers = Coda_process.peers_exn worker in
      Print.printf "sum_worker: %d\n" res ;
      Print.printf !"peers: %{sexp: Host_and_port.t list}\n" peers;
      let%bind strongest_ledgers = Coda_process.strongest_ledgers_exn worker in
      let count = ref 0 in
      don't_wait_for begin
        Linear_pipe.iter strongest_ledgers 
          ~f:(fun () -> 
              Print.printf "got ledger\n";
              incr count;
              Deferred.unit)
      end;
      let%bind () = after (Time.Span.of_sec 60.) in
      Print.printf "ledgers: %d\n" !count;
      let%bind _ = Coda_process.disconnect worker in
      Deferred.unit
    )

let name = "coda-block-production-test"

let command =
  Command.async_spec ~summary:"Simple use of Async Rpc_parallel V2"
    Command.Spec.(empty)
    main

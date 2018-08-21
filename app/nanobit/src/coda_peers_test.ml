open Core
open Async
open Coda_worker
open Coda_processes

let main () =
  let%bind program_dir = Unix.getcwd () in
  let n = 3 in
  Coda_processes.init () ;
  Coda_processes.spawn_local_processes_exn n ~program_dir ~f:(fun workers ->
      let _, _, expected_peers = Coda_processes.net_configs n in
      let%bind _ = after (Time.Span.of_sec 10.) in
      Deferred.all_unit
        (List.map2_exn workers expected_peers ~f:(fun worker expected_peers ->
             let%bind peers = Coda_process.peers_exn worker in
             (*Print.printf !"peers: %{sexp: Host_and_port.t list} %{sexp: Host_and_port.t list}\n" peers expected_peers;*)
             assert (peers = expected_peers) ;
             Deferred.unit )) )

let name = "coda-peers-test"

let command =
  Command.async_spec ~summary:"Simple use of Async Rpc_parallel V2"
    Command.Spec.(empty)
    main

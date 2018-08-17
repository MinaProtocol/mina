open Core
open Async
open Nanobit_base
open Coda_main
open Spawner
open Coda_worker
open Coda_process_wrapper

let run =
  let open Deferred.Let_syntax in
  Coda_process_wrapper.command (fun program_dir host executable_path ->
      Coda_process_wrapper.make_master program_dir host executable_path
        (fun master ->
          let reader = Master.new_states master in
          Linear_pipe.iter reader ~f:(fun x ->
              Print.printf "read message\n" ;
              return () ) ) )

let name = "coda-block-production-test"

let command =
  Command.async
    ~summary:
      "A test that shows how a coda instance can identify another instance as \
       it's peer"
    run

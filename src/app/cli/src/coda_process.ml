open Core
open Async
open Coda_worker
open Coda_main

module Make (Kernel : Kernel_intf) = struct
  module Coda_worker = Coda_worker.Make (Kernel)

  type t = Coda_worker.Connection.t * Process.t * Coda_worker.Input.t

  let spawn_exn (config : Coda_worker.Input.t) =
    let%bind conn, process =
      Coda_worker.spawn_in_foreground_exn ~env:config.env
        ~on_failure:Error.raise ~cd:config.program_dir ~shutdown_on:Disconnect
        ~connection_state_init_arg:()
        ~connection_timeout:(Time.Span.of_sec 15.) config
    in
    File_system.dup_stdout process ;
    File_system.dup_stderr process ;
    return (conn, process, config)

  let local_config ?(transition_interval = 1000.0) ?proposal_interval ~peers
      ~discovery_port ~external_port ~program_dir ~should_propose
      ~snark_worker_config ~work_selection () =
    let host = "127.0.0.1" in
    let conf_dir =
      Filename.temp_dir_name
      ^/ String.init 16 ~f:(fun _ -> (Int.to_string (Random.int 10)).[0])
    in
    let config =
      { Coda_worker.Input.host
      ; env=
          Option.map proposal_interval ~f:(fun interval ->
              [("CODA_PROPOSAL_INTERVAL", Int.to_string interval)] )
          |> Option.value ~default:[]
      ; should_propose
      ; transition_interval
      ; external_port
      ; snark_worker_config
      ; work_selection
      ; peers
      ; conf_dir
      ; program_dir
      ; discovery_port }
    in
    config

  let disconnect (conn, proc, _) =
    let%bind () = Coda_worker.Connection.close conn in
    let%bind _ : Unix.Exit_or_signal.t = Process.wait proc in
    return ()

  let peers_exn (conn, proc, _) =
    Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.peers ~arg:()

  let get_balance_exn (conn, proc, _) pk =
    Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.get_balance
      ~arg:pk

  let send_transaction_exn (conn, proc, _) sk pk amount fee =
    Coda_worker.Connection.run_exn conn
      ~f:Coda_worker.functions.send_transaction ~arg:(sk, pk, amount, fee)

  let strongest_ledgers_exn (conn, proc, _) =
    let%map r =
      Coda_worker.Connection.run_exn conn
        ~f:Coda_worker.functions.strongest_ledgers ~arg:()
    in
    Linear_pipe.wrap_reader r
end

open Core
open Async
open Coda_worker
open Coda_base
open Coda_main
open Pipe_lib

type t = Coda_worker.Connection.t * Process.t * Coda_worker.Input.t

let spawn_exn (config : Coda_worker.Input.t) =
  let%bind conn, process =
    Coda_worker.spawn_in_foreground_exn ~env:config.env ~on_failure:Error.raise
      ~cd:config.program_dir ~shutdown_on:Disconnect
      ~connection_state_init_arg:() ~connection_timeout:(Time.Span.of_sec 15.)
      config
  in
  File_system.dup_stdout process ;
  File_system.dup_stderr process ;
  return (conn, process, config)

let local_config ?proposal_interval ~peers ~discovery_port ~external_port
    ~acceptable_delay ~program_dir ~proposer ~snark_worker_config
    ~work_selection ~offset ~trace_dir () =
  let host = "127.0.0.1" in
  let conf_dir =
    Filename.temp_dir_name
    ^/ String.init 16 ~f:(fun _ -> (Int.to_string (Random.int 10)).[0])
  in
  let config =
    { Coda_worker.Input.host
    ; env=
        ( "CODA_TIME_OFFSET"
        , Time.Span.to_int63_seconds_round_down_exn offset
          |> Int63.to_int
          |> Option.value_exn ?here:None ?message:None ?error:None
          |> Int.to_string )
        :: ( Core.Unix.environment () |> Array.to_list
           |> List.filter_map
                ~f:
                  (Fn.compose
                     (function [a; b] -> Some (a, b) | _ -> None)
                     (String.split ~on:'=')) )
    ; proposer
    ; external_port
    ; snark_worker_config
    ; work_selection
    ; peers
    ; conf_dir
    ; trace_dir
    ; program_dir
    ; acceptable_delay
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

let send_payment_exn (conn, proc, _) sk pk amount fee memo =
  Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.send_payment
    ~arg:(sk, pk, amount, fee, memo)

let prove_receipt_exn (conn, proc, _) proving_receipt resulting_receipt =
  Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.prove_receipt
    ~arg:(proving_receipt, resulting_receipt)

let strongest_ledgers_exn (conn, proc, _) =
  let%map r =
    Coda_worker.Connection.run_exn conn
      ~f:Coda_worker.functions.strongest_ledgers ~arg:()
  in
  Linear_pipe.wrap_reader r

let start_exn (conn, proc, _) =
  Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.start ~arg:()

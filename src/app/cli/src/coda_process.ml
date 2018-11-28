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
    ~program_dir ~should_propose ~snark_worker_config ~work_selection () =
  let host = "127.0.0.1" in
  let conf_dir =
    Filename.temp_dir_name
    ^/ String.init 16 ~f:(fun _ -> (Int.to_string (Random.int 10)).[0])
  in
  let config =
    { Coda_worker.Input.host
    ; env=
        (* FIXME #1089: what about all the PoS env vars? Shouldn't we just inherit? *)
        Option.map proposal_interval ~f:(fun interval ->
            [ ("CODA_PROPOSAL_INTERVAL", Int.to_string interval)
            ; ("CODA_SLOT_INTERVAL", Int.to_string interval) ] )
        |> Option.value ~default:[]
    ; should_propose
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

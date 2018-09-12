open Core
open Async
open Coda_worker
open Coda_main

module Make
    (Ledger_proof : Ledger_proof_intf)
    (Kernel : Kernel_intf with type Ledger_proof.t = Ledger_proof.t)
    (Coda : Coda_intf.S with type ledger_proof = Ledger_proof.t) =
struct
  module Coda_worker = Coda_worker.Make (Ledger_proof) (Kernel) (Coda)

  type t = Coda_worker.Connection.t * Process.t

  let spawn_exn (config: Coda_worker.Input.t) =
    let%bind conn, process =
      Coda_worker.spawn_in_foreground_exn ~env:config.env
        ~on_failure:Error.raise ~cd:config.program_dir ~shutdown_on:Disconnect
        ~connection_state_init_arg:()
        ~connection_timeout:(Time.Span.of_sec 15.) config
    in
    File_system.dup_stdout process ;
    File_system.dup_stderr process ;
    return (conn, process)

  let spawn_local_exn ?(transition_interval= 1000.0) ?proposal_interval ~peers
      ~discovery_port ~external_port ~program_dir ~should_propose
      ~snark_worker_config ~f () =
    let host = "127.0.0.1" in
    let conf_dir =
      "/tmp/" ^ String.init 16 ~f:(fun _ -> (Int.to_string (Random.int 10)).[0])
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
      ; peers
      ; conf_dir
      ; program_dir
      ; discovery_port }
    in
    File_system.with_temp_dirs [conf_dir] ~f:(fun () ->
        let%bind worker = spawn_exn config in
        f worker )

  let disconnect (conn, proc) =
    let%bind () = Coda_worker.Connection.close conn in
    let%bind _ : Unix.Exit_or_signal.t = Process.wait proc in
    return ()

  let peers_exn (conn, proc) =
    Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.peers ~arg:()

  let get_balance_exn (conn, proc) pk =
    Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.get_balance
      ~arg:pk

  let send_transaction_exn (conn, proc) sk pk amount fee =
    Coda_worker.Connection.run_exn conn
      ~f:Coda_worker.functions.send_transaction ~arg:(sk, pk, amount, fee)

  let strongest_ledgers_exn (conn, proc) =
    let%map r =
      Coda_worker.Connection.run_exn conn
        ~f:Coda_worker.functions.strongest_ledgers ~arg:()
    in
    Linear_pipe.wrap_reader r
end

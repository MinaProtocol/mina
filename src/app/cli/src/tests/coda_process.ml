[%%import
"../../../../config.mlh"]

open Core
open Async
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

let local_config ?proposal_interval:_ ~peers ~addrs_and_ports ~acceptable_delay
    ~program_dir ~proposer ~snark_worker_key ~work_selection_method ~offset
    ~trace_dir ~max_concurrent_connections ~is_archive_node () =
  let conf_dir =
    Filename.temp_dir_name
    ^/ String.init 16 ~f:(fun _ -> (Int.to_string (Random.int 10)).[0])
  in
  let config =
    { Coda_worker.Input.addrs_and_ports
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
    ; snark_worker_key
    ; work_selection_method
    ; peers
    ; conf_dir
    ; trace_dir
    ; program_dir
    ; acceptable_delay
    ; is_archive_node
    ; max_concurrent_connections }
  in
  config

let peers_exn (conn, _proc, _) =
  Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.peers ~arg:()

let get_balance_exn (conn, _proc, _) pk =
  Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.get_balance
    ~arg:pk

let get_nonce_exn (conn, _proc, _) pk =
  Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.get_nonce
    ~arg:pk

let root_length_exn (conn, _proc, _) =
  Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.root_length
    ~arg:()

let send_user_command_exn (conn, _proc, _) sk pk amount fee memo =
  Coda_worker.Connection.run_exn conn
    ~f:Coda_worker.functions.send_user_command
    ~arg:(sk, pk, amount, fee, memo)

let process_user_command_exn (conn, _proc, _) cmd =
  Coda_worker.Connection.run_exn conn
    ~f:Coda_worker.functions.process_user_command ~arg:cmd

let prove_receipt_exn (conn, _proc, _) proving_receipt resulting_receipt =
  Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.prove_receipt
    ~arg:(proving_receipt, resulting_receipt)

let sync_status_exn (conn, _proc, _) =
  let%map r =
    Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.sync_status
      ~arg:()
  in
  Linear_pipe.wrap_reader r

let verified_transitions_exn (conn, _proc, _) =
  let%map r =
    Coda_worker.Connection.run_exn conn
      ~f:Coda_worker.functions.verified_transitions ~arg:()
  in
  Linear_pipe.wrap_reader r

(* TODO: 2836 delete once transition_frontier extensions refactoring gets in *)
let validated_transitions_keyswaptest_exn (conn, _, _) =
  let%map r =
    Coda_worker.Connection.run_exn conn
      ~f:Coda_worker.functions.validated_transitions_keyswaptest ~arg:()
  in
  Linear_pipe.wrap_reader r

let new_block_exn (conn, _proc, __) key =
  let%map r =
    Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.new_block
      ~arg:key
  in
  Linear_pipe.wrap_reader r

let get_all_transitions (conn, _proc, __) key =
  Coda_worker.Connection.run_exn conn
    ~f:Coda_worker.functions.get_all_transitions ~arg:key

let root_diff_exn (conn, _proc, _) =
  let%map r =
    Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.root_diff
      ~arg:()
  in
  Linear_pipe.wrap_reader r

let start_exn (conn, _proc, _) =
  Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.start ~arg:()

let new_user_command_exn (conn, _proc, _) pk =
  Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.new_user_command
    ~arg:pk

let get_all_user_commands_exn (conn, _proc, _) pk =
  Coda_worker.Connection.run_exn conn
    ~f:Coda_worker.functions.get_all_user_commands ~arg:pk

let dump_tf (conn, _proc, _) =
  Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.dump_tf ~arg:()

let best_path (conn, _proc, _) =
  Coda_worker.Connection.run_exn conn ~f:Coda_worker.functions.best_path
    ~arg:()

let replace_snark_worker_key (conn, _proc, _) key =
  Coda_worker.Connection.run_exn conn
    ~f:Coda_worker.functions.replace_snark_worker_key ~arg:key

let stop_snark_worker (conn, _, _) =
  Coda_worker.Connection.run_exn conn
    ~f:Coda_worker.functions.stop_snark_worker ~arg:()

let disconnect ((conn, proc, _) as t) =
  (* This kills any strangling snark worker process *)
  let%bind () = stop_snark_worker t in
  let%bind () = Coda_worker.Connection.close conn in
  let%map (_ : Unix.Exit_or_signal.t) = Process.wait proc in
  ()

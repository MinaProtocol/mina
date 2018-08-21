open Core
open Async
open Coda_worker

module Coda_process = struct
  type t = Coda_worker.Connection.t * Process.t

  let spawn_exn config =
    let%bind conn, process =
      Coda_worker.spawn_in_foreground_exn ~on_failure:Error.raise
        ~cd:config.Coda_worker.program_dir ~shutdown_on:Disconnect
        ~connection_state_init_arg:()
        ~connection_timeout:(Time.Span.of_sec 15.) config
    in
    File_system.dup_stdout process ;
    File_system.dup_stderr process ;
    return (conn, process)

  let spawn_local_exn ~peers ~port ~gossip_port ~program_dir ~f =
    let host = "127.0.0.1" in
    let conf_dir =
      "/tmp/" ^ String.init 16 ~f:(fun _ -> (Int.to_string (Random.int 10)).[0])
    in
    let config =
      { Coda_worker.host
      ; my_port= port
      ; peers
      ; conf_dir
      ; program_dir
      ; gossip_port }
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

  let strongest_ledgers_exn (conn, proc) =
    let%map r =
      Coda_worker.Connection.run_exn conn
        ~f:Coda_worker.functions.strongest_ledgers ~arg:()
    in
    Linear_pipe.wrap_reader r
end

module Coda_processes = struct
  let init () = Parallel.init_master ()

  let net_configs n =
    let ports = List.init n ~f:(fun i -> 23000 + i) in
    let gossip_ports = List.init n ~f:(fun i -> 24000 + i) in
    let all_peers =
      List.map ports ~f:(fun p -> Host_and_port.create "127.0.0.1" p)
    in
    let peers =
      List.init n ~f:(fun i ->
          List.take all_peers i @ List.drop all_peers (i + 1) )
    in
    (ports, gossip_ports, peers)

  let spawn_local_processes_exn n ~program_dir ~f =
    let fns =
      let ports, gossip_ports, peers = net_configs n in
      let peers = [] :: List.drop peers 1 in
      List.map3_exn ports gossip_ports peers ~f:(fun port gossip_port peers ->
          Coda_process.spawn_local_exn ~peers ~port ~gossip_port ~program_dir
      )
    in
    let first = List.hd_exn fns in
    let rest = List.drop fns 1 in
    let scoped =
      List.fold (List.rev rest)
        ~init:(fun ws -> f (List.rev ws))
        ~f:(fun last fn ws -> fn (fun w -> last (w :: ws)))
    in
    first (fun w ->
        let%bind () = after (Time.Span.of_sec 3.) in
        scoped [w] )
end

open Core
open Async
open Coda_worker
open Coda_main

let name = "coda-transitive-peers-test"

open Coda_processes

let main () =
  let%bind program_dir = Unix.getcwd () in
  let n = 3 in
  let logger = Logger.create () in
  let proposal_interval = Consensus.Constants.block_window_duration_ms in
  let acceptable_delay =
    Time.Span.of_ms
      (proposal_interval * Consensus.Constants.delta |> Float.of_int)
  in
  let work_selection = Protocols.Coda_pow.Work_selection.Seq in
  Coda_processes.init () ;
  let trace_dir = Unix.getenv "CODA_TRACING" in
  let max_concurrent_connections = Some 10 in
  let configs =
    Coda_processes.local_configs n ~program_dir ~proposal_interval
      ~acceptable_delay ~snark_worker_public_keys:None
      ~proposers:(Fn.const None) ~work_selection ~trace_dir
      ~max_concurrent_connections
  in
  let%bind workers = Coda_processes.spawn_local_processes_exn configs in
  let discovery_ports, external_ports, peers =
    Coda_processes.net_configs (n + 1)
  in
  let expected_peers = List.nth_exn peers n in
  let peers = [List.hd_exn expected_peers] in
  let external_port = List.nth_exn external_ports n in
  let discovery_port = List.nth_exn discovery_ports n in
  Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
    !"connecting to peers %{sexp: Host_and_port.t list}\n"
    peers ;
  let config =
    Coda_process.local_config ~peers ~external_port ~discovery_port
      ~acceptable_delay ~snark_worker_config:None ~proposer:None ~program_dir
      ~work_selection ~trace_dir ~offset:Time.Span.zero ()
      ~max_concurrent_connections
  in
  let%bind worker = Coda_process.spawn_exn config in
  let%bind _ = after (Time.Span.of_sec 10.) in
  let%bind peers = Coda_process.peers_exn worker in
  Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
    !"got peers %{sexp: Network_peer.Peer.t list} %{sexp: Host_and_port.t list}\n"
    peers expected_peers ;
  let module S = Host_and_port.Set in
  assert (
    S.equal
      (S.of_list
         (peers |> List.map ~f:Network_peer.Peer.to_discovery_host_and_port))
      (S.of_list expected_peers) ) ;
  let%bind () = Coda_process.disconnect worker in
  Deferred.List.iter workers ~f:Coda_process.disconnect

let command =
  Command.async
    ~summary:"test that second-degree peers show up in the peer list"
    (Command.Param.return main)

open Core
open Async
open Coda_worker
open Coda_main
open Coda_processes

let name = "coda-peers-test"

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
  let configs =
    Coda_processes.local_configs n ~program_dir ~proposal_interval
      ~acceptable_delay ~snark_worker_public_keys:None
      ~proposers:(Fn.const None) ~work_selection
      ~trace_dir:(Unix.getenv "CODA_TRACING")
      ~max_concurrent_connections:(Some 10)
  in
  let%bind workers = Coda_processes.spawn_local_processes_exn configs in
  let _, _, expected_peers = Coda_processes.net_configs n in
  let%bind _ = after (Time.Span.of_sec 10.) in
  let%bind () =
    Deferred.all_unit
      (List.map2_exn workers expected_peers ~f:(fun worker expected_peers ->
           let%map peers = Coda_process.peers_exn worker in
           Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
             !"got peers %{sexp: Network_peer.Peer.t list} %{sexp: \
               Host_and_port.t list}\n"
             peers expected_peers ;
           let module S = Host_and_port.Set in
           assert (
             S.equal
               (S.of_list
                  ( peers
                  |> List.map ~f:Network_peer.Peer.to_discovery_host_and_port
                  ))
               (S.of_list expected_peers) ) ))
  in
  Deferred.List.iter workers ~f:Coda_process.disconnect

let command =
  Command.async
    ~summary:"integration test with two peers spawned alongside a seed"
    (Command.Param.return main)

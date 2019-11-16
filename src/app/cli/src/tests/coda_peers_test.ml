open Core
open Async

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
  let work_selection_method = Cli_lib.Arg_type.Sequence in
  Coda_processes.init () ;
  let configs =
    Coda_processes.local_configs n ~program_dir ~proposal_interval
      ~acceptable_delay ~snark_worker_public_keys:None
      ~proposers:(Fn.const None) ~work_selection_method
      ~trace_dir:(Unix.getenv "CODA_TRACING")
      ~chain_id:name
  in
  let%bind workers = Coda_processes.spawn_local_processes_exn configs in
  let all_configs = Coda_processes.net_configs n in
  let expected_peers_per_peer =
    List.init n ~f:(fun i -> List.filteri all_configs ~f:(fun j _ -> i <> j))
  in
  let%bind _ = after (Time.Span.of_sec 10.) in
  let%bind () =
    Deferred.all_unit
      (List.map2_exn workers expected_peers_per_peer
         ~f:(fun worker expected_peers ->
           let%map peers = Coda_process.peers_exn worker in
           let expected_ports_and_ips =
             Host_and_port.Set.of_list
               (List.map
                  ~f:(fun p ->
                    Host_and_port.create
                      ~host:(Unix.Inet_addr.to_string p.bind_ip)
                      ~port:p.libp2p_port )
                  expected_peers)
           in
           let actual_ports_and_ips =
             Host_and_port.Set.of_list
               (List.map
                  ~f:(fun p ->
                    Host_and_port.create
                      ~host:(Unix.Inet_addr.to_string p.Network_peer.Peer.host)
                      ~port:p.libp2p_port )
                  peers)
           in
           Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
             !"got peers %{sexp: Network_peer.Peer.t list} %{sexp: \
               Node_addrs_and_ports.t list}\n"
             peers expected_peers ;
           assert (
             Host_and_port.Set.equal expected_ports_and_ips
               actual_ports_and_ips ) ))
  in
  Deferred.List.iter workers ~f:(Coda_process.disconnect ~logger)

let command =
  Command.async
    ~summary:"integration test with two peers spawned alongside a seed"
    (Command.Param.return main)

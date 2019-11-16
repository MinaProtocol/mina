open Core
open Async

let name = "coda-transitive-peers-test"

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
  let trace_dir = Unix.getenv "CODA_TRACING" in
  let configs =
    Coda_processes.local_configs n ~program_dir ~proposal_interval
      ~acceptable_delay ~snark_worker_public_keys:None
      ~proposers:(Fn.const None) ~work_selection_method ~trace_dir
      ~chain_id:name
  in
  let%bind workers = Coda_processes.spawn_local_processes_exn configs in
  let addrs_and_ports_list = Coda_processes.net_configs (n + 1) in
  let addrs_and_ports =
    List.nth_exn addrs_and_ports_list n |> Node_addrs_and_ports.to_display
  in
  let expected_ports_and_ips =
    Host_and_port.Set.of_list
      (List.map
         ~f:(fun p ->
           Host_and_port.create
             ~host:(Unix.Inet_addr.to_string p.bind_ip)
             ~port:p.libp2p_port )
         addrs_and_ports_list)
  in
  Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
    !"connecting to peers %{sexp: Node_addrs_and_ports.Display.t list}\n"
    (List.map ~f:Node_addrs_and_ports.to_display addrs_and_ports_list) ;
  let config =
    Coda_process.local_config ~addrs_and_ports ~acceptable_delay
      ~snark_worker_key:None ~proposer:None ~program_dir ~work_selection_method
      ~trace_dir ~offset:Time.Span.zero () ~is_archive_node:false
      ~chain_id:name
  in
  let%bind worker = Coda_process.spawn_exn config in
  let%bind _ = after (Time.Span.of_sec 10.) in
  let%bind peers = Coda_process.peers_exn worker in
  Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
    !"got peers %{sexp: Network_peer.Peer.t list} %{sexp: Host_and_port.Set.t}\n"
    peers expected_ports_and_ips ;
  let actual_ports_and_ips =
    Host_and_port.Set.of_list
      (List.map
         ~f:(fun p ->
           Host_and_port.create
             ~host:(Unix.Inet_addr.to_string p.Network_peer.Peer.host)
             ~port:p.libp2p_port )
         peers)
  in
  assert (Host_and_port.Set.equal expected_ports_and_ips actual_ports_and_ips) ;
  let%bind () = Coda_process.disconnect worker ~logger in
  Deferred.List.iter workers ~f:(Coda_process.disconnect ~logger)

let command =
  Command.async
    ~summary:"test that second-degree peers show up in the peer list"
    (Command.Param.return main)

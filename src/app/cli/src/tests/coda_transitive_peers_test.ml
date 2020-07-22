open Core
open Async

let name = "coda-transitive-peers-test"

let runtime_config = Runtime_config.Test_configs.split_snarkless

let main () =
  let logger = Logger.create () in
  let%bind precomputed_values, _runtime_config =
    Genesis_ledger_helper.init_from_config_file ~logger ~may_generate:false
      ~proof_level:None
      (Lazy.force runtime_config)
    >>| Or_error.ok_exn
  in
  let consensus_constants = precomputed_values.consensus_constants in
  let%bind program_dir = Unix.getcwd () in
  let n = 3 in
  let block_production_interval =
    consensus_constants.block_window_duration_ms |> Block_time.Span.to_ms
    |> Int64.to_int_exn
  in
  let acceptable_delay =
    Time.Span.of_ms
      ( block_production_interval
        * Unsigned.UInt32.to_int consensus_constants.delta
      |> Float.of_int )
  in
  let work_selection_method =
    Cli_lib.Arg_type.Work_selection_method.Sequence
  in
  Coda_processes.init () ;
  let trace_dir = Unix.getenv "CODA_TRACING" in
  let max_concurrent_connections = None in
  let%bind configs =
    Coda_processes.local_configs n ~program_dir ~block_production_interval
      ~acceptable_delay ~chain_id:name ~snark_worker_public_keys:None
      ~block_production_keys:(Fn.const None) ~work_selection_method ~trace_dir
      ~max_concurrent_connections
      ~runtime_config:
        (Genesis_ledger_helper.extract_runtime_config precomputed_values)
  in
  let%bind workers = Coda_processes.spawn_local_processes_exn configs in
  let%bind net_configs = Coda_processes.net_configs (n + 1) in
  let addrs_and_ports_list, peers = net_configs in
  let expected_peers = List.nth_exn peers n in
  let peers =
    List.map ~f:Node_addrs_and_ports.to_multiaddr_exn
      [List.hd_exn expected_peers]
  in
  let addrs_and_ports =
    List.nth_exn addrs_and_ports_list n
    |> fst |> Node_addrs_and_ports.to_display
  in
  let libp2p_keypair = List.nth_exn addrs_and_ports_list n |> snd in
  Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
    !"connecting to peers %{sexp: string list}\n"
    peers ;
  let config =
    Coda_process.local_config ~is_seed:true ~peers ~addrs_and_ports
      ~acceptable_delay ~chain_id:name ~libp2p_keypair ~net_configs
      ~snark_worker_key:None ~block_production_key:None ~program_dir
      ~work_selection_method ~trace_dir ~offset:Time.Span.zero ()
      ~max_concurrent_connections ~is_archive_rocksdb:false
      ~archive_process_location:None
      ~runtime_config:
        (Genesis_ledger_helper.extract_runtime_config precomputed_values)
  in
  let%bind worker = Coda_process.spawn_exn config in
  let%bind _ = after (Time.Span.of_sec 10.) in
  let%bind peers = Coda_process.peers_exn worker in
  Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
    !"got peers %{sexp: Network_peer.Peer.t list} %{sexp: \
      Node_addrs_and_ports.t list}\n"
    peers expected_peers ;
  let module S = Host_and_port.Set in
  assert (
    S.equal
      (S.of_list
         ( peers
         |> List.map ~f:(fun p ->
                Host_and_port.create
                  ~host:(Unix.Inet_addr.to_string p.Network_peer.Peer.host)
                  ~port:p.libp2p_port ) ))
      (S.of_list
         (List.map
            ~f:(fun p ->
              Host_and_port.create
                ~host:(Unix.Inet_addr.to_string p.external_ip)
                ~port:p.libp2p_port )
            expected_peers)) ) ;
  let%bind () = Coda_process.disconnect worker ~logger in
  Deferred.List.iter workers ~f:(Coda_process.disconnect ~logger)

let command =
  Command.async
    ~summary:"test that second-degree peers show up in the peer list"
    (Command.Param.return main)

[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Cli_lib
open Signature_lib
open Init
module YJ = Yojson.Safe

[%%check_ocaml_word_size
64]

[%%if
fake_hash]

let maybe_sleep s = after (Time.Span.of_sec s)

[%%else]

let maybe_sleep _ = Deferred.unit

[%%endif]

let chain_id =
  lazy
    (let genesis_state_hash =
       (Lazy.force Coda_state.Genesis_protocol_state.t).hash
       |> State_hash.to_base58_check
     in
     let all_snark_keys =
       List.fold_left ~f:( ^ ) ~init:"" Snark_keys.key_hashes
     in
     let b2 = Blake2.digest_string (genesis_state_hash ^ all_snark_keys) in
     Blake2.to_hex b2)

[%%inject
"daemon_expiry", daemon_expiry]

let daemon logger =
  let open Command.Let_syntax in
  let open Cli_lib.Arg_type in
  Command.async ~summary:"Coda daemon"
    (let%map_open conf_dir = Cli_lib.Flag.conf_dir
     and propose_key =
       flag "propose-key"
         ~doc:
           "KEYFILE Private key file for the block producer. You cannot \
            provide both `propose-key` and `propose-public-key`. (default: \
            don't produce blocks)"
         (optional string)
     and initial_peers_raw =
       flag "peer"
         ~doc:
           "HOST:PORT TCP daemon communications (can be given multiple times)"
         (listed peer)
     and run_snark_worker_flag =
       flag "run-snark-worker"
         ~doc:"PUBLICKEY Run the SNARK worker with this public key"
         (optional public_key_compressed)
     and work_selection_method_flag =
       flag "work-selection"
         ~doc:
           "seq|rand Choose work sequentially (seq) or randomly (rand) \
            (default: rand)"
         (optional work_selection_method)
     and external_port =
       flag "external-port"
         ~doc:
           (sprintf
              "PORT Base server port for daemon TCP (discovery UDP on port+1) \
               (default: %d)"
              Port.default_external)
         (optional int16)
     and client_port =
       flag "client-port"
         ~doc:
           (sprintf "PORT Client to daemon local communication (default: %d)"
              Port.default_client)
         (optional int16)
     and rest_server_port =
       flag "rest-port"
         ~doc:
           (sprintf
              "PORT local REST-server for daemon interaction (default: %d)"
              Port.default_rest)
         (optional int16)
     and metrics_server_port =
       flag "metrics-port"
         ~doc:
           "PORT metrics server for scraping via Prometheus (default no \
            metrics-server)"
         (optional int16)
     and external_ip_opt =
       flag "external-ip"
         ~doc:
           "IP External IP address for other nodes to connect to. You only \
            need to set this if auto-discovery fails for some reason."
         (optional string)
     and bind_ip_opt =
       flag "bind-ip" ~doc:"IP IP of network interface to use"
         (optional string)
     and is_background =
       flag "background" no_arg ~doc:"Run process on the background"
     and is_archive_node =
       flag "archive" no_arg ~doc:"Archive all blocks heard"
     and log_json =
       flag "log-json" no_arg
         ~doc:"Print daemon log output as JSON (default: plain text)"
     and log_level =
       flag "log-level" (optional string)
         ~doc:"Set daemon log level (default: Info)"
     and snark_work_fee =
       flag "snark-worker-fee"
         ~doc:
           (sprintf
              "FEE Amount a worker wants to get compensated for generating a \
               snark proof (default: %d)"
              (Currency.Fee.to_int Cli_lib.Default.snark_worker_fee))
         (optional txn_fee)
     and work_reassignment_wait =
       flag "work-reassignment-wait" (optional int)
         ~doc:
           (sprintf
              "WAIT-TIME in ms before a snark-work is reassigned (default: \
               %dms)"
              Cli_lib.Default.work_reassignment_wait)
     and enable_tracing =
       flag "tracing" no_arg ~doc:"Trace into $config-directory/$pid.trace"
     and insecure_rest_server =
       flag "insecure-rest-server" no_arg
         ~doc:
           "Have REST server listen on all addresses, not just localhost \
            (this is INSECURE, make sure your firewall is configured \
            correctly!)"
     and limit_connections =
       flag "limit-concurrent-connections"
         ~doc:
           "true|false Limit the number of concurrent connections per IP \
            address (default: true)"
         (optional bool)
     (*TODO: This is being added to log all the snark works received for the
     beta-testnet challenge. We might want to remove this later?*)
     and log_received_snark_pool_diff =
       flag "log-snark-work-gossip"
         ~doc:
           "true|false Log snark-pool diff received from peers (default: false)"
         (optional bool)
     and log_received_blocks =
       flag "log-received-blocks"
         ~doc:"true|false Log blocks received from peers (default: false)"
         (optional bool)
     and log_transaction_pool_diff =
       flag "log-txn-pool-gossip"
         ~doc:
           "true|false Log transaction-pool diff received from peers \
            (default: false)"
         (optional bool)
     and enable_libp2p =
       flag "libp2p-discovery" no_arg ~doc:"Use libp2p for peer discovery"
     and libp2p_port =
       flag "libp2p-port" (optional int)
         ~doc:"Port to use for libp2p (default: 28675)"
     and disable_haskell =
       flag "disable-old-discovery" no_arg
         ~doc:"Disable the old discovery mechanism"
     and libp2p_keypair =
       flag "libp2p-keypair" (optional string)
         ~doc:
           "Keypair (generated from `coda advanced generate-libp2p-keypair`) \
            to use with libp2p (default: generate new keypair)"
     and libp2p_peers_raw =
       flag "libp2p-peer"
         ~doc:
           "/ip4/HOST/tcp/PORT/ipfs/PEERID initial \"bootstrap\" peers for \
            libp2p discovery"
         (listed string)
     in
     fun () ->
       let open Deferred.Let_syntax in
       let compute_conf_dir home =
         Option.value ~default:(home ^/ Cli_lib.Default.conf_dir_name) conf_dir
       in
       let%bind log_level =
         match log_level with
         | None ->
             Deferred.return Logger.Level.Info
         | Some log_level_str_with_case -> (
             let open Logger in
             let log_level_str = String.lowercase log_level_str_with_case in
             match Level.of_string log_level_str with
             | Error _ ->
                 eprintf "Received unknown log-level %s. Expected one of: %s\n"
                   log_level_str
                   ( Level.all |> List.map ~f:Level.show
                   |> List.map ~f:String.lowercase
                   |> String.concat ~sep:", " ) ;
                 exit 14
             | Ok ll ->
                 Deferred.return ll )
       in
       let%bind conf_dir =
         if is_background then
           let home = Core.Sys.home_directory () in
           let conf_dir = compute_conf_dir home in
           Deferred.return conf_dir
         else Sys.home_directory () >>| compute_conf_dir
       in
       let () =
         match Core.Sys.file_exists conf_dir with
         | `Yes ->
             ()
         | _ ->
             Core.Unix.mkdir_p conf_dir
       in
       let () =
         if is_background then (
           Core.printf "Starting background coda daemon. (Log Dir: %s)\n%!"
             conf_dir ;
           Daemon.daemonize ~redirect_stdout:`Dev_null
             ~redirect_stderr:`Dev_null () )
         else ()
       in
       let stdout_log_processor =
         if log_json then Logger.Processor.raw ()
         else
           Logger.Processor.pretty ~log_level
             ~config:
               { Logproc_lib.Interpolator.mode= Inline
               ; max_interpolation_length= 50
               ; pretty_print= true }
       in
       Logger.Consumer_registry.register ~id:"default"
         ~processor:stdout_log_processor
         ~transport:(Logger.Transport.stdout ()) ;
       (* 512MB logrotate max size = 1GB max filesystem usage *)
       let logrotate_max_size = 1024 * 1024 * 512 in
       Logger.Consumer_registry.register ~id:"raw_persistent"
         ~processor:(Logger.Processor.raw ())
         ~transport:
           (Logger.Transport.File_system.dumb_logrotate ~directory:conf_dir
              ~max_size:logrotate_max_size) ;
       Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
         "Coda daemon is booting up; built with commit $commit on branch \
          $branch"
         ~metadata:
           [ ("commit", `String Coda_version.commit_id)
           ; ("branch", `String Coda_version.branch) ] ;
       if not @@ String.equal daemon_expiry "never" then (
         Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
           "Daemon will expire at $exp"
           ~metadata:[("exp", `String daemon_expiry)] ;
         let tm =
           (* same approach as in Consensus.Constants.genesis_state_timestamp *)
           let default_timezone = Core.Time.Zone.of_utc_offset ~hours:(-8) in
           Core.Time.of_string_gen
             ~if_no_timezone:(`Use_this_one default_timezone) daemon_expiry
         in
         Clock.run_at tm
           (fun () ->
             Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
               "Daemon has expired, shutting down" ;
             Core.exit 0 )
           () ) ;
       Logger.info ~module_:__MODULE__ ~location:__LOC__ logger
         "Booting may take several seconds, please wait" ;
       let libp2p_keypair =
         Option.map libp2p_keypair ~f:(fun s ->
             match Coda_net2.Keypair.of_string s with
             | Ok kp ->
                 kp
             | Error e ->
                 Logger.fatal logger "failed to parse -libp2p-keypair: $err"
                   ~module_:__MODULE__ ~location:__LOC__
                   ~metadata:[("err", `String (Error.to_string_hum e))] ;
                 Core.exit 19 )
       in
       (* Check if the config files are for the current version.
        * WARNING: Deleting ALL the files in the config directory if there is
        * a version mismatch *)
       (* When persistence is added back, this needs to be revisited
        * to handle persistence related files properly *)
       let%bind () =
         let del_files dir =
           let rec all_files dirname basename =
             let fullname = Filename.concat dirname basename in
             match%bind Sys.is_directory fullname with
             | `Yes ->
                 let%map dirs, files =
                   Sys.ls_dir fullname
                   >>= Deferred.List.map ~f:(all_files fullname)
                   >>| List.unzip
                 in
                 let dirs =
                   if String.equal dirname conf_dir then List.concat dirs
                   else List.append (List.concat dirs) [fullname]
                 in
                 (dirs, List.concat files)
             | _ ->
                 Deferred.return ([], [fullname])
           in
           let%bind dirs, files = all_files dir "" in
           let%bind () =
             Deferred.List.iter files ~f:(fun file -> Sys.remove file)
           in
           Deferred.List.iter dirs ~f:(fun file -> Unix.rmdir file)
         in
         let make_version ~wipe_dir =
           let%bind () =
             if wipe_dir then del_files conf_dir else Deferred.unit
           in
           let%bind wr = Writer.open_file (conf_dir ^/ "coda.version") in
           Writer.write_line wr Coda_version.commit_id ;
           Writer.close wr
         in
         match%bind
           Monitor.try_with_or_error (fun () ->
               let%bind r = Reader.open_file (conf_dir ^/ "coda.version") in
               match%map Pipe.to_list (Reader.lines r) with
               | [] ->
                   ""
               | s ->
                   List.hd_exn s )
         with
         | Ok c ->
             if String.equal c Coda_version.commit_id then return ()
             else (
               Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
                 "Different version of Coda detected in config directory \
                  $config_directory, removing existing configuration"
                 ~metadata:[("config_directory", `String conf_dir)] ;
               make_version ~wipe_dir:true )
         | Error e ->
             Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
               ~metadata:[("error", `String (Error.to_string_mach e))]
               "Error reading coda.version: $error" ;
             Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
               "Failed to read coda.version, cleaning up the config directory \
                $config_directory"
               ~metadata:[("config_directory", `String conf_dir)] ;
             make_version ~wipe_dir:false
       in
       don't_wait_for
         (let bytes_per_word = Sys.word_size / 8 in
          let rec loop () =
            let stat = Gc.stat () in
            Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
              "OCaml memory statistics"
              ~metadata:
                [ ("heap_size", `Int (stat.heap_words * bytes_per_word))
                ; ("heap_chunks", `Int stat.heap_chunks)
                ; ("max_heap_size", `Int (stat.top_heap_words * bytes_per_word))
                ; ("live_size", `Int (stat.live_words * bytes_per_word))
                ; ("live_blocks", `Int stat.live_blocks) ] ;
            let%bind () = after @@ Time.Span.of_min 10. in
            loop ()
          in
          loop ()) ;
       Parallel.init_master () ;
       let monitor = Async.Monitor.create ~name:"coda" () in
       let module Coda_initialization = struct
         type ('a, 'b, 'c) t =
           {coda: 'a; client_whitelist: 'b; rest_server_port: 'c}
       end in
       let coda_initialization_deferred () =
         let%bind config =
           match%map
             Monitor.try_with_or_error ~extract_exn:true (fun () ->
                 let%bind r = Reader.open_file (conf_dir ^/ "daemon.json") in
                 let%map contents =
                   Pipe.to_list (Reader.lines r)
                   >>| fun ss -> String.concat ~sep:"\n" ss
                 in
                 YJ.from_string ~fname:"daemon.json" contents )
           with
           | Ok c ->
               Some c
           | Error e ->
               Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                 "Error reading daemon.json: $error"
                 ~metadata:[("error", `String (Error.to_string_mach e))] ;
               None
         in
         let maybe_from_config (type a) (f : YJ.json -> a option)
             (keyname : string) (actual_value : a option) : a option =
           let open Option.Let_syntax in
           let open YJ.Util in
           match actual_value with
           | Some v ->
               Some v
           | None ->
               let%bind config = config in
               let%bind json_val = to_option Fn.id (member keyname config) in
               f json_val
         in
         let or_from_config map keyname actual_value ~default =
           match maybe_from_config map keyname actual_value with
           | Some x ->
               x
           | None ->
               Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                 "Key '$key' not found in the config file, using default"
                 ~metadata:[("key", `String keyname)] ;
               default
         in
         let external_port : int =
           or_from_config YJ.Util.to_int_option "external-port"
             ~default:Port.default_external external_port
         in
         let client_port =
           or_from_config YJ.Util.to_int_option "client-port"
             ~default:Port.default_client client_port
         in
         let rest_server_port =
           or_from_config YJ.Util.to_int_option "rest-port"
             ~default:Port.default_rest rest_server_port
         in
         ignore libp2p_port ;
         (* FIXME HACK: make this configurable when we can pass the port in the CLI *)
         let libp2p_port =
           (*
           or_from_config YJ.Util.to_int_option "libp2p-port"
             ~default:Port.default_libp2p libp2p_port *)
           Port.default_libp2p
         in
         let snark_work_fee_flag =
           let json_to_currency_fee_option json =
             YJ.Util.to_int_option json |> Option.map ~f:Currency.Fee.of_int
           in
           or_from_config json_to_currency_fee_option "snark-worker-fee"
             ~default:Cli_lib.Default.snark_worker_fee snark_work_fee
         in
         let max_concurrent_connections =
           if
             or_from_config YJ.Util.to_bool_option "max-concurrent-connections"
               ~default:true limit_connections
           then Some 10
           else None
         in
         let work_selection_method =
           or_from_config
             (Fn.compose Option.return
                (Fn.compose work_selection_method_val YJ.Util.to_string))
             "work-selection" ~default:Cli_lib.Arg_type.Random
             work_selection_method_flag
         in
         let work_reassignment_wait =
           or_from_config YJ.Util.to_int_option "work-reassignment-wait"
             ~default:Cli_lib.Default.work_reassignment_wait
             work_reassignment_wait
         in
         let log_received_snark_pool_diff =
           or_from_config YJ.Util.to_bool_option "log-snark-work-gossip"
             ~default:false log_received_snark_pool_diff
         in
         let log_received_blocks =
           or_from_config YJ.Util.to_bool_option "log-received-blocks"
             ~default:false log_received_blocks
         in
         let log_transaction_pool_diff =
           or_from_config YJ.Util.to_bool_option "log-txn-pool-gossip"
             ~default:false log_transaction_pool_diff
         in
         let log_gossip_heard =
           { Coda_networking.Gossip_net.Config.snark_pool_diff=
               log_received_snark_pool_diff
           ; transaction_pool_diff= log_transaction_pool_diff
           ; new_state= log_received_blocks }
         in
         let initial_peers_raw =
           List.concat
             [ initial_peers_raw
             ; List.map ~f:Host_and_port.of_string
               @@ or_from_config
                    (Fn.compose Option.some
                       (YJ.Util.convert_each YJ.Util.to_string))
                    "peers" None ~default:[] ]
         in
         let discovery_port = external_port + 1 in
         if enable_tracing then Coda_tracing.start conf_dir |> don't_wait_for ;
         let%bind initial_peers_cleaned_lists =
           (* for each provided peer, lookup all its addresses *)
           Deferred.List.filter_map ~how:(`Max_concurrent_jobs 8)
             initial_peers_raw ~f:(fun addr ->
               let host = Host_and_port.host addr in
               match%map
                 Monitor.try_with_or_error (fun () ->
                     Async.Unix.Host.getbyname_exn host )
               with
               | Ok unix_host ->
                   (* assume addresses is nonempty *)
                   let addresses = Array.to_list unix_host.addresses in
                   let port = Host_and_port.port addr in
                   Some
                     (List.map addresses ~f:(fun inet_addr ->
                          Host_and_port.create
                            ~host:(Unix.Inet_addr.to_string inet_addr)
                            ~port ))
               | Error e ->
                   Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                     "Error on getbyname: $error"
                     ~metadata:[("error", `String (Error.to_string_mach e))] ;
                   Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                     "Failed to get addresses for host $host, skipping"
                     ~metadata:[("host", `String host)] ;
                   None )
         in
         (* flatten list of lists of host-and-ports *)
         let initial_peers_cleaned = List.concat initial_peers_cleaned_lists in
         let%bind () =
           if
             List.length initial_peers_raw <> 0
             && List.length initial_peers_cleaned = 0
           then (
             eprintf "Error: failed to connect to any peers\n" ;
             exit 10 )
           else Deferred.unit
         in
         let%bind external_ip =
           match external_ip_opt with
           | None ->
               Find_ip.find ~logger
           | Some ip ->
               return @@ Unix.Inet_addr.of_string ip
         in
         let bind_ip =
           Option.value bind_ip_opt ~default:"0.0.0.0"
           |> Unix.Inet_addr.of_string
         in
         let addrs_and_ports : Kademlia.Node_addrs_and_ports.t =
           { external_ip
           ; bind_ip
           ; discovery_port
           ; communication_port= external_port
           ; client_port
           ; libp2p_port }
         in
         let%bind propose_keypair =
           match propose_key with
           | Some sk_file ->
               let%map kp = Secrets.Keypair.Terminal_stdin.read_exn sk_file in
               Some kp
           | None ->
               return None
         in
         let%bind client_whitelist =
           Reader.load_sexp
             (conf_dir ^/ "client_whitelist")
             [%of_sexp: Unix.Inet_addr.Blocking_sexp.t list]
           >>| Or_error.ok
         in
         Stream.iter
           (Async.Scheduler.long_cycles
              ~at_least:(sec 0.5 |> Time_ns.Span.of_span_float_round_nearest))
           ~f:(fun span ->
             Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
               "long async cycle %s"
               (Time_ns.Span.to_string span) ) ;
         let trace_database_initialization typ location =
           Logger.trace logger "Creating %s at %s" ~module_:__MODULE__
             ~location typ
         in
         let trust_dir = conf_dir ^/ "trust" in
         let () = Snark_params.set_chunked_hashing true in
         let%bind () = Async.Unix.mkdir ~p:() trust_dir in
         let transition_frontier_location =
           conf_dir ^/ "transition_frontier"
         in
         let trust_system = Trust_system.create ~db_dir:trust_dir in
         trace_database_initialization "trust_system" __LOC__ trust_dir ;
         let time_controller =
           Block_time.Controller.create @@ Block_time.Controller.basic ~logger
         in
         let initial_propose_keypairs =
           propose_keypair |> Option.to_list |> Keypair.Set.of_list
         in
         let consensus_local_state =
           Consensus.Data.Local_state.create
             ( Option.map propose_keypair ~f:(fun keypair ->
                   let open Keypair in
                   Public_key.compress keypair.public_key )
             |> Option.to_list |> Public_key.Compressed.Set.of_list )
         in
         trace_database_initialization "consensus local state" __LOC__
           trust_dir ;
         let net_config =
           { Coda_networking.Config.logger
           ; trust_system
           ; time_controller
           ; consensus_local_state
           ; gossip_net_params=
               { timeout= Time.Span.of_sec 3.
               ; logger
               ; target_peer_count= 8
               ; conf_dir
               ; chain_id= Lazy.force chain_id
               ; initial_peers= initial_peers_cleaned
               ; addrs_and_ports
               ; trust_system
               ; log_gossip_heard
               ; enable_libp2p
               ; disable_haskell
               ; libp2p_keypair
               ; libp2p_peers=
                   List.map ~f:Coda_net2.Multiaddr.of_string libp2p_peers_raw
               ; max_concurrent_connections } }
         in
         let receipt_chain_dir_name = conf_dir ^/ "receipt_chain" in
         let%bind () = Async.Unix.mkdir ~p:() receipt_chain_dir_name in
         let receipt_chain_database =
           Coda_base.Receipt_chain_database.create
             ~directory:receipt_chain_dir_name
         in
         trace_database_initialization "receipt_chain_database" __LOC__
           receipt_chain_dir_name ;
         let transaction_database_dir = conf_dir ^/ "transaction" in
         let%bind () = Async.Unix.mkdir ~p:() transaction_database_dir in
         let transaction_database =
           Auxiliary_database.Transaction_database.create ~logger
             transaction_database_dir
         in
         trace_database_initialization "transaction_database" __LOC__
           transaction_database_dir ;
         let external_transition_database_dir =
           conf_dir ^/ "external_transition_database"
         in
         let%bind () =
           Async.Unix.mkdir ~p:() external_transition_database_dir
         in
         let external_transition_database =
           Auxiliary_database.External_transition_database.create ~logger
             external_transition_database_dir
         in
         (* log terminated child processes *)
         let pids = Child_processes.Termination.create_pid_set () in
         let rec terminated_child_loop () =
           match
             try Unix.wait_nohang `Any
             with
             | Unix.Unix_error (errno, _, _)
             when Int.equal (Unix.Error.compare errno Unix.ECHILD) 0
                  (* no child processes exist *)
             ->
               None
           with
           | None ->
               (* no children have terminated, wait to check again *)
               let%bind () = Async.after (Time.Span.of_min 1.) in
               terminated_child_loop ()
           | Some (child_pid, exit_or_signal) ->
               let child_pid_metadata =
                 [("child_pid", `Int (Pid.to_int child_pid))]
               in
               ( match exit_or_signal with
               | Ok () ->
                   Logger.info logger ~module_:__MODULE__ ~location:__LOC__
                     "Daemon child process $child_pid terminated with exit \
                      code 0"
                     ~metadata:child_pid_metadata
               | Error err -> (
                 match err with
                 | `Signal signal ->
                     Logger.info logger ~module_:__MODULE__ ~location:__LOC__
                       "Daemon child process $child_pid terminated after \
                        receiving signal $signal"
                       ~metadata:
                         ( ("signal", `String (Signal.to_string signal))
                         :: child_pid_metadata )
                 | `Exit_non_zero exit_code ->
                     Logger.info logger ~module_:__MODULE__ ~location:__LOC__
                       "Daemon child process $child_pid terminated with \
                        nonzero exit code $exit_code"
                       ~metadata:
                         (("exit_code", `Int exit_code) :: child_pid_metadata)
                 ) ) ;
               (* terminate daemon if children registered *)
               Child_processes.Termination.check_terminated_child pids
                 child_pid logger ;
               (* check for other terminated children, without waiting *)
               terminated_child_loop ()
         in
         Deferred.don't_wait_for @@ terminated_child_loop () ;
         let%map coda =
           Coda_lib.create
             (Coda_lib.Config.make ~logger ~pids ~trust_system ~conf_dir
                ~net_config
                ~work_selection_method:
                  (Cli_lib.Arg_type.work_selection_method_to_module
                     work_selection_method)
                ~snark_worker_config:
                  { Coda_lib.Config.Snark_worker_config.initial_snark_worker_key=
                      run_snark_worker_flag
                  ; shutdown_on_disconnect= true }
                ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
                ~wallets_disk_location:(conf_dir ^/ "wallets")
                ~ledger_db_location:(conf_dir ^/ "ledger_db")
                ~snark_work_fee:snark_work_fee_flag ~receipt_chain_database
                ~transition_frontier_location ~time_controller
                ~initial_propose_keypairs ~monitor ~consensus_local_state
                ~transaction_database ~external_transition_database
                ~is_archive_node ~work_reassignment_wait ())
         in
         {Coda_initialization.coda; client_whitelist; rest_server_port}
       in
       (* Breaks a dependency cycle with monitor initilization and coda *)
       let coda_ref : Coda_lib.t option ref = ref None in
       Coda_run.handle_shutdown ~monitor ~conf_dir ~top_logger:logger coda_ref ;
       Async.Scheduler.within' ~monitor
       @@ fun () ->
       let%bind {Coda_initialization.coda; client_whitelist; rest_server_port}
           =
         coda_initialization_deferred ()
       in
       coda_ref := Some coda ;
       let%bind () = maybe_sleep 3. in
       let web_service = Web_pipe.get_service () in
       Web_pipe.run_service coda web_service ~conf_dir ~logger ;
       Coda_run.setup_local_server ?client_whitelist ~rest_server_port
         ~insecure_rest_server coda ;
       let%bind () = Coda_lib.start coda in
       let%bind () =
         Option.map metrics_server_port ~f:(fun port ->
             Coda_metrics.server ~port ~logger >>| ignore )
         |> Option.value ~default:Deferred.unit
       in
       Logger.info logger ~module_:__MODULE__ ~location:__LOC__
         "Daemon ready. Clients can now connect" ;
       Async.never ())

[%%if
force_updates]

let rec ensure_testnet_id_still_good logger =
  let open Cohttp_async in
  let recheck_soon = 0.1 in
  let recheck_later = 1.0 in
  let try_later hrs =
    Async.Clock.run_after (Time.Span.of_hr hrs)
      (fun () -> don't_wait_for @@ ensure_testnet_id_still_good logger)
      ()
  in
  let soon_minutes = Int.of_float (60.0 *. recheck_soon) in
  match%bind
    Monitor.try_with_or_error (fun () ->
        Client.get (Uri.of_string "http://updates.o1test.net/testnet_id") )
  with
  | Error e ->
      Logger.error logger ~module_:__MODULE__ ~location:__LOC__
        "Exception while trying to fetch testnet_id: $error. Trying again in \
         $retry_minutes minutes"
        ~metadata:
          [ ("error", `String (Error.to_string_hum e))
          ; ("retry_minutes", `Int soon_minutes) ] ;
      try_later recheck_soon ;
      Deferred.unit
  | Ok (resp, body) -> (
      if resp.status <> `OK then (
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__
          "HTTP response status $HTTP_status while getting testnet id, \
           checking again in $retry_minutes minutes."
          ~metadata:
            [ ( "HTTP_status"
              , `String (Cohttp.Code.string_of_status resp.status) )
            ; ("retry_minutes", `Int soon_minutes) ] ;
        try_later recheck_soon ;
        Deferred.unit )
      else
        let%bind body_string = Body.to_string body in
        let valid_ids =
          String.split ~on:'\n' body_string
          |> List.map ~f:(Fn.compose Git_sha.of_string String.strip)
        in
        (* Maybe the Git_sha.of_string is a bit gratuitous *)
        let finish local_id remote_ids =
          let str x = Git_sha.sexp_of_t x |> Sexp.to_string in
          eprintf
            "The version for the testnet has changed, and this client \
             (version %s) is no longer compatible. Please download the latest \
             Coda software!\n\
             Valid versions:\n\
             %s\n"
            ( local_id |> Option.map ~f:str
            |> Option.value ~default:"[COMMIT_SHA1 not set]" )
            remote_ids ;
          exit 13
        in
        match commit_id with
        | None ->
            finish None body_string
        | Some sha ->
            if
              List.exists valid_ids ~f:(fun remote_id ->
                  Git_sha.equal sha remote_id )
            then ( try_later recheck_later ; Deferred.unit )
            else finish commit_id body_string )

[%%else]

let ensure_testnet_id_still_good _ = Deferred.unit

[%%endif]

let snark_hashes =
  let open Command.Let_syntax in
  Command.basic ~summary:"List hashes of proving and verification keys"
    [%map_open
      let json = Cli_lib.Flag.json in
      let print = Core.printf "%s\n%!" in
      fun () ->
        if json then
          print
            (Yojson.Safe.to_string
               (Snark_keys.key_hashes_to_yojson Snark_keys.key_hashes))
        else List.iter Snark_keys.key_hashes ~f:print]

let internal_commands =
  [ (Snark_worker.Intf.command_name, Snark_worker.command)
  ; ("snark-hashes", snark_hashes) ]

let coda_commands logger =
  [ ("daemon", daemon logger)
  ; ("client", Client.command)
  ; ("advanced", Client.advanced)
  ; ("internal", Command.group ~summary:"Internal commands" internal_commands)
  ; (Parallel.worker_command_name, Parallel.worker_command)
  ; ("transaction-snark-profiler", Transaction_snark_profiler.command) ]

[%%if
new_cli]

let coda_commands logger =
  ("accounts", Client.accounts) :: coda_commands logger

[%%endif]

[%%if
integration_tests]

module type Integration_test = sig
  val name : string

  val command : Async.Command.t
end

let coda_commands logger =
  let open Tests in
  let group =
    List.map
      ~f:(fun (module T) -> (T.name, T.command))
      ( [ (module Coda_peers_test)
        ; (module Coda_block_production_test)
        ; (module Coda_shared_state_test)
        ; (module Coda_transitive_peers_test)
        ; (module Coda_shared_prefix_test)
        ; (module Coda_shared_prefix_multiproposer_test)
        ; (module Coda_five_nodes_test)
        ; (module Coda_restart_node_test)
        ; (module Coda_receipt_chain_test)
        ; (module Coda_restarts_and_txns_holy_grail)
        ; (module Coda_bootstrap_test)
        ; (module Coda_batch_payment_test)
        ; (module Coda_long_fork)
        ; (module Coda_txns_and_restart_non_proposers)
        ; (module Coda_delegation_test)
        ; (module Coda_change_snark_worker_test)
        ; (module Full_test)
        ; (module Transaction_snark_profiler)
        ; (module Coda_archive_node_test) ]
        : (module Integration_test) list )
  in
  coda_commands logger
  @ [("integration-tests", Command.group ~summary:"Integration tests" group)]

[%%endif]

let print_version_help coda_exe version =
  (* mimic Jane Street command help *)
  let lines =
    [ "print version information"
    ; ""
    ; sprintf "  %s %s" (Filename.basename coda_exe) version
    ; ""
    ; "=== flags ==="
    ; ""
    ; "  [-help]  print this help text and exit"
    ; "           (alias: -?)" ]
  in
  List.iter lines ~f:(Core.printf "%s\n%!")

let print_version_info () =
  Core.printf "Commit %s on branch %s\n"
    (String.sub Coda_version.commit_id ~pos:0 ~len:7)
    Coda_version.branch

let () =
  Random.self_init () ;
  let logger = Logger.create ~initialize_default_consumer:false () in
  don't_wait_for (ensure_testnet_id_still_good logger) ;
  (* Turn on snark debugging in prod for now *)
  Snarky.Snark.set_eval_constraints true ;
  (* intercept command-line processing for "version", because we don't
     use the Jane Street scripts that generate their version information
   *)
  (let make_list_mem ss s = List.mem ss s ~equal:String.equal in
   let is_version_cmd = make_list_mem ["version"; "-version"] in
   let is_help_flag = make_list_mem ["-help"; "-?"] in
   match Sys.argv with
   | [|_coda_exe; version|] when is_version_cmd version ->
       print_version_info ()
   | [|coda_exe; version; help|]
     when is_version_cmd version && is_help_flag help ->
       print_version_help coda_exe version
   | _ ->
       Command.run
         (Command.group ~summary:"Coda" ~preserve_subcommand_order:()
            (coda_commands logger))) ;
  Core.exit 0

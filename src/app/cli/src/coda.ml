[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Blockchain_snark
open Cli_lib
open Coda_main
module YJ = Yojson.Safe
module Git_sha = Daemon_rpcs.Types.Git_sha

[%%if
tracing]

let start_tracing () =
  Writer.open_file
    (sprintf "/tmp/coda-profile-%d" (Unix.getpid () |> Pid.to_int))
  >>| O1trace.start_tracing

[%%else]

let start_tracing () = Deferred.unit

[%%endif]

let commit_id = Option.map [%getenv "CODA_COMMIT_SHA1"] ~f:Git_sha.of_string

module type Coda_intf = sig
  type ledger_proof

  module Make (Init : Init_intf) () : Main_intf
end

let daemon log =
  let open Command.Let_syntax in
  let open Cli_lib.Arg_type in
  Command.async ~summary:"Coda daemon"
    (let%map_open conf_dir =
       flag "config-directory" ~doc:"DIR Configuration directory"
         (optional file)
     and propose_key =
       flag "propose-key"
         ~doc:
           "FILE Private key file for the proposing transitions \
            (default:don't propose)"
         (optional file)
     and peers =
       flag "peer"
         ~doc:
           "HOST:PORT TCP daemon communications (can be given multiple times)"
         (listed peer)
     and run_snark_worker_flag =
       flag "run-snark-worker" ~doc:"KEY Run the SNARK worker with a key"
         (optional public_key_compressed)
     and work_selection_flag =
       flag "work-selection"
         ~doc:
           "seq|rand Choose work sequentially (seq) or randomly (rand) \
            (default: seq)"
         (optional work_selection)
     and external_port =
       flag "external-port"
         ~doc:
           (Printf.sprintf
              "PORT Base server port for daemon TCP (discovery UDP on port+1) \
               (default: %d)"
              Port.default_external)
         (optional int16)
     and client_port =
       flag "client-port"
         ~doc:
           (Printf.sprintf
              "PORT Client to daemon local communication (default: %d)"
              Port.default_client)
         (optional int16)
     and rest_server_port =
       flag "rest-port"
         ~doc:
           "PORT local REST-server for daemon interaction (default no \
            rest-server)"
         (optional int16)
     and ip =
       flag "ip" ~doc:"IP External IP address for others to connect"
         (optional string)
     and transaction_capacity_log_2 =
       flag "txn-capacity"
         ~doc:
           "CAPACITY_LOG_2 Log of capacity of transactions per transition \
            (default: 4)"
         (optional int)
     and is_background =
       flag "background" no_arg ~doc:"Run process on the background"
     and snark_work_fee =
       flag "snark-worker-fee"
         ~doc:
           "FEE Amount a worker wants to get compensated for generating a \
            snark proof"
         (optional int)
     and sexp_logging =
       flag "sexp-logging" no_arg
         ~doc:"Use S-expressions in log output, instead of JSON"
     in
     fun () ->
       let open Deferred.Let_syntax in
       let compute_conf_dir home =
         Option.value ~default:(home ^/ ".coda-config") conf_dir
       in
       let%bind conf_dir =
         if is_background then (
           let home = Core.Sys.home_directory () in
           let conf_dir = compute_conf_dir home in
           Core.printf "Starting background coda daemon. (Log Dir: %s)\n%!"
             conf_dir ;
           Daemon.daemonize
             ~redirect_stdout:(`File_append (conf_dir ^/ "coda.log"))
             ~redirect_stderr:(`File_append (conf_dir ^/ "coda.log"))
             () ;
           Deferred.return conf_dir )
         else Sys.home_directory () >>| compute_conf_dir
       in
       Parallel.init_master () ;
       ignore (Logger.set_sexp_logging sexp_logging) ;
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
         | Ok c -> Some c
         | Error e ->
             Logger.trace log "error reading daemon.json: %s"
               (Error.to_string_mach e) ;
             Logger.warn log "failed to read daemon.json, not using it" ;
             None
       in
       let maybe_from_config (type a) (f : YJ.json -> a option)
           (keyname : string) (actual_value : a option) : a option =
         let open Option.Let_syntax in
         let open YJ.Util in
         match actual_value with
         | Some v -> Some v
         | None ->
             let%bind config = config in
             let%bind json_val = to_option Fn.id (member keyname config) in
             f json_val
       in
       let or_from_config map keyname actual_value ~default =
         match maybe_from_config map keyname actual_value with
         | Some x -> x
         | None ->
             Logger.info log "didn't find %s in the config file, using default"
               keyname ;
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
       let transaction_capacity_log_2 =
         or_from_config YJ.Util.to_int_option "txn-capacity" ~default:8
           transaction_capacity_log_2
       in
       let snark_work_fee_flag =
         Currency.Fee.of_int
           (or_from_config YJ.Util.to_int_option "snark-worker-fee" ~default:0
              snark_work_fee)
       in
       let rest_server_port =
         maybe_from_config YJ.Util.to_int_option "rest-port" rest_server_port
       in
       let work_selection =
         or_from_config
           (Fn.compose Option.return
              (Fn.compose work_selection_val YJ.Util.to_string))
           "work-selection" ~default:Protocols.Coda_pow.Work_selection.Seq
           work_selection_flag
       in
       let peers =
         List.concat
           [ peers
           ; List.map ~f:Host_and_port.of_string
             @@ or_from_config
                  (Fn.compose Option.some
                     (YJ.Util.convert_each YJ.Util.to_string))
                  "peers" None ~default:[] ]
       in
       let discovery_port = external_port + 1 in
       let%bind () = Unix.mkdir ~p:() conf_dir in
       let%bind initial_peers_raw =
         match peers with
         | _ :: _ -> return peers
         | [] -> (
             let peers_path = conf_dir ^/ "peers" in
             match%bind
               Reader.load_sexp peers_path [%of_sexp: Host_and_port.t list]
             with
             | Ok ls -> return ls
             | Error e ->
                 let default_initial_peers = [] in
                 let%map () =
                   Writer.save_sexp peers_path
                     ([%sexp_of: Host_and_port.t list] default_initial_peers)
                 in
                 [] )
       in
       let%bind initial_peers =
         Deferred.List.filter_map ~how:(`Max_concurrent_jobs 8)
           initial_peers_raw ~f:(fun addr ->
             let host = Host_and_port.host addr in
             match%bind
               Monitor.try_with_or_error (fun () ->
                   Unix.Inet_addr.of_string_or_getbyname host )
             with
             | Ok inet_addr ->
                 return
                 @@ Some
                      (Host_and_port.create
                         ~host:(Unix.Inet_addr.to_string inet_addr)
                         ~port:(Host_and_port.port addr))
             | Error e ->
                 Logger.trace log "getaddr exception: %s"
                   (Error.to_string_mach e) ;
                 Logger.error log "failed to look up address for %s, skipping"
                   host ;
                 return None )
       in
       let%bind () =
         if List.length peers <> 0 && List.length initial_peers = 0 then (
           eprintf "Error: failed to connect to any peers\n" ;
           exit 1 )
         else Deferred.unit
       in
       let%bind ip =
         match ip with None -> Find_ip.find () | Some ip -> return ip
       in
       let me =
         (Host_and_port.create ~host:ip ~port:discovery_port, external_port)
       in
       let sequence maybe_def =
         match maybe_def with
         | Some def -> Deferred.map def ~f:Option.return
         | None -> Deferred.return None
       in
       let%bind propose_keypair =
         Option.map ~f:Cli_lib.Keypair.Terminal_stdin.read_exn propose_key
         |> sequence
       in
       let%bind client_whitelist =
         Reader.load_sexp
           (conf_dir ^/ "client_whitelist")
           [%of_sexp: Unix.Inet_addr.Blocking_sexp.t list]
         >>| Or_error.ok
       in
       let module Config0 = struct
         let logger = log

         let conf_dir = conf_dir

         let lbc_tree_max_depth = `Finite 50

         let propose_keypair = propose_keypair

         let genesis_proof = Precomputed_values.base_proof

         let transaction_capacity_log_2 = transaction_capacity_log_2

         let commit_id = commit_id

         let work_selection = work_selection
       end in
       let%bind (module Init) =
         make_init
           ~should_propose:(Option.is_some propose_keypair)
           (module Config0)
       in
       let module M = Coda_main.Make_coda (Init) in
       let module Run = Run (Config0) (M) in
       Async.Scheduler.report_long_cycle_times ~cutoff:(sec 0.5) () ;
       let%bind () =
         let open M in
         let run_snark_worker_action =
           Option.value_map run_snark_worker_flag ~default:`Don't_run
             ~f:(fun k -> `With_public_key k )
         in
         let banlist_dir_name = conf_dir ^/ "banlist" in
         let%bind () = Async.Unix.mkdir ~p:() banlist_dir_name in
         let suspicious_dir = banlist_dir_name ^/ "suspicious" in
         let punished_dir = banlist_dir_name ^/ "banned" in
         let%bind () = Async.Unix.mkdir ~p:() suspicious_dir in
         let%bind () = Async.Unix.mkdir ~p:() punished_dir in
         let%bind () = start_tracing () in
         let banlist =
           Coda_base.Banlist.create ~suspicious_dir ~punished_dir
         in
         let time_controller = Inputs.Time.Controller.create () in
         let net_config =
           { Inputs.Net.Config.parent_log= log
           ; time_controller
           ; gossip_net_params=
               { timeout= Time.Span.of_sec 1.
               ; parent_log= log
               ; target_peer_count= 8
               ; conf_dir
               ; initial_peers
               ; me
               ; banlist } }
         in
         let receipt_chain_dir_name = conf_dir ^/ "receipt_chain" in
         let%bind () = Async.Unix.mkdir ~p:() receipt_chain_dir_name in
         let receipt_chain_database =
           Coda_base.Receipt_chain_database.create
             ~directory:receipt_chain_dir_name
         in
         let%map coda =
           Run.create
             (Run.Config.make ~log ~net_config
                ~run_snark_worker:(Option.is_some run_snark_worker_flag)
                ~ledger_builder_persistant_location:
                  (conf_dir ^/ "ledger_builder")
                ~transaction_pool_disk_location:(conf_dir ^/ "transaction_pool")
                ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
                ~ledger_db_location:(conf_dir ^/ "ledger_db")
                ~snark_work_fee:snark_work_fee_flag ~receipt_chain_database
                ~time_controller ?propose_keypair:Config0.propose_keypair ()
                ~banlist)
         in
         let web_service = Web_pipe.get_service () in
         Web_pipe.run_service (module Run) coda web_service ~conf_dir ~log ;
         Run.setup_local_server ?client_whitelist ?rest_server_port ~coda
           ~client_port ~log () ;
         Run.run_snark_worker ~log ~client_port run_snark_worker_action
       in
       Async.never ())

[%%if
force_updates]

let rec ensure_testnet_id_still_good log =
  let open Cohttp_async in
  let recheck_soon = 0.1 in
  let recheck_later = 1.0 in
  let try_later hrs =
    Async.Clock.run_after (Time.Span.of_hr hrs)
      (fun () -> don't_wait_for @@ ensure_testnet_id_still_good log)
      ()
  in
  match%bind
    Monitor.try_with_or_error (fun () ->
        Client.get (Uri.of_string "http://updates.o1test.net/testnet_id") )
  with
  | Error e ->
      Logger.error log
        "exception while trying to fetch testnet_id, trying again in 6 minutes" ;
      try_later recheck_soon ;
      Deferred.unit
  | Ok (resp, body) -> (
      if resp.status <> `OK then (
        try_later recheck_soon ;
        Logger.error log
          "HTTP response status %s while getting testnet id, checking again \
           in 6 minutes."
          (Cohttp.Code.string_of_status resp.status) ;
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
             %s"
            ( local_id |> Option.map ~f:str
            |> Option.value ~default:"[COMMIT_SHA1 not set]" )
            remote_ids ;
          exit 1
        in
        match commit_id with
        | None -> finish None body_string
        | Some sha ->
            if
              List.exists valid_ids ~f:(fun remote_id ->
                  Git_sha.equal sha remote_id )
            then ( try_later recheck_later ; Deferred.unit )
            else finish commit_id body_string )

[%%else]

let ensure_testnet_id_still_good _ = Deferred.unit

[%%endif]

[%%if
with_snark]

let internal_commands =
  [(Snark_worker_lib.Intf.command_name, Snark_worker_lib.Prod.Worker.command)]

[%%else]

let internal_commands =
  [(Snark_worker_lib.Intf.command_name, Snark_worker_lib.Debug.Worker.command)]

[%%endif]

let coda_commands log =
  [ (Parallel.worker_command_name, Parallel.worker_command)
  ; ("internal", Command.group ~summary:"Internal commands" internal_commands)
  ; ("daemon", daemon log)
  ; ("client", Client.command)
  ; ("transaction-snark-profiler", Transaction_snark_profiler.command) ]

[%%if
integration_tests]

let coda_commands log =
  let group =
    [ (Coda_peers_test.name, Coda_peers_test.command)
    ; (Coda_block_production_test.name, Coda_block_production_test.command)
    ; (Coda_shared_state_test.name, Coda_shared_state_test.command)
    ; (Coda_transitive_peers_test.name, Coda_transitive_peers_test.command)
    ; (Coda_shared_prefix_test.name, Coda_shared_prefix_test.command)
    ; (Coda_restart_node_test.name, Coda_restart_node_test.command)
    ; (Coda_receipt_chain_test.name, Coda_receipt_chain_test.command)
    ; ("full-test", Full_test.command)
    ; ("transaction-snark-profiler", Transaction_snark_profiler.command) ]
  in
  coda_commands log
  @ [("integration-tests", Command.group ~summary:"Integration tests" group)]

[%%endif]

let () =
  Random.self_init () ;
  let log = Logger.create () in
  don't_wait_for (ensure_testnet_id_still_good log) ;
  Command.run (Command.group ~summary:"Coda" (coda_commands log)) ;
  Core.exit 0

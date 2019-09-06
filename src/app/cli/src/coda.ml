[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Blockchain_snark
open Cli_lib
open Coda_inputs
open Signature_lib
module YJ = Yojson.Safe
module Git_sha = Daemon_rpcs.Types.Git_sha

[%%if
fake_hash]

let maybe_sleep s = after (Time.Span.of_sec s)

[%%else]

let maybe_sleep _ = Deferred.unit

[%%endif]

let commit_id = Option.map [%getenv "CODA_COMMIT_SHA1"] ~f:Git_sha.of_string

module type Coda_intf = sig
  type ledger_proof

  module Make (Init : Init_intf) () : Main_intf
end

let daemon logger =
  let open Command.Let_syntax in
  let open Cli_lib.Arg_type in
  Command.async ~summary:"Coda daemon"
    (let%map_open conf_dir =
       flag "config-directory" ~doc:"DIR Configuration directory"
         (optional string)
     and propose_key =
       flag "propose-key"
         ~doc:
           "KEYFILE Private key file for the proposing transitions. You \
            cannot provide both `propose-key` and `propose-public-key`. \
            (default:don't propose)"
         (optional string)
     and propose_public_key =
       flag "propose-public-key"
         ~doc:
           "PUBLICKEY Public key for the associated private key that is being \
            tracked by this daemon. You cannot provide both `propose-key` and \
            `propose-public-key`. (default: don't propose)"
         (optional public_key_compressed)
     and initial_peers_raw =
       flag "peer"
         ~doc:
           "HOST:PORT TCP daemon communications (can be given multiple times)"
         (listed peer)
     and run_snark_worker_flag =
       flag "run-snark-worker"
         ~doc:"PUBLICKEY Run the SNARK worker with this public key"
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
     and snark_work_fee =
       flag "snark-worker-fee"
         ~doc:
           (Printf.sprintf
              "FEE Amount a worker wants to get compensated for generating a \
               snark proof (default: %d)"
              (Currency.Fee.to_int Cli_lib.Fee.default_snark_worker))
         (optional txn_fee)
     and sexp_logging =
       flag "sexp-logging" no_arg
         ~doc:"Use S-expressions in log output, instead of JSON"
     and enable_tracing =
       flag "tracing" no_arg ~doc:"Trace into $config-directory/$pid.trace"
     and limit_connections =
       flag "limit-concurrent-connections"
         ~doc:
           "true|false Limit the number of concurrent connections per IP \
            address (default:true)"
         (optional bool)
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
               "error reading daemon.json: %s" (Error.to_string_mach e) ;
             Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
               "failed to read daemon.json, not using it" ;
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
             Logger.info logger ~module_:__MODULE__ ~location:__LOC__
               "didn't find %s in the config file, using default" keyname ;
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
       let snark_work_fee_flag =
         let json_to_currency_fee_option json =
           YJ.Util.to_int_option json |> Option.map ~f:Currency.Fee.of_int
         in
         or_from_config json_to_currency_fee_option "snark-worker-fee"
           ~default:Cli_lib.Fee.default_snark_worker snark_work_fee
       in
       let max_concurrent_connections =
         if
           or_from_config YJ.Util.to_bool_option "max-concurrent-connections"
             ~default:true limit_connections
         then Some 10
         else None
       in
       let rest_server_port =
         maybe_from_config YJ.Util.to_int_option "rest-port" rest_server_port
       in
       let work_selection =
         or_from_config
           (Fn.compose Option.return
              (Fn.compose work_selection_val YJ.Util.to_string))
           "work-selection" ~default:Cli_lib.Arg_type.Seq work_selection_flag
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
       let%bind () = Unix.mkdir ~p:() conf_dir in
       if enable_tracing then Coda_tracing.start conf_dir |> don't_wait_for ;
       let%bind initial_peers_cleaned =
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
                 Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                   "getaddr exception: %s" (Error.to_string_mach e) ;
                 Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                   "failed to look up address for %s, skipping" host ;
                 return None )
       in
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
             Find_ip.find ()
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
         ; communication_port= external_port }
       in
       let wallets_disk_location = conf_dir ^/ "wallets" in
       (* HACK: Until we can properly change propose keys at runtime we'll
        * suffer by accepting a propose_public_key flag and reloading the wallet
        * db here to find the keypair for the pubkey *)
       let%bind propose_keypair =
         match (propose_key, propose_public_key) with
         | Some _, Some _ ->
             eprintf
               "Error: You cannot provide both `propose-key` and \
                `propose-public-key`" ;
             exit 11
         | Some sk_file, None ->
             Secrets.Keypair.Terminal_stdin.read_exn sk_file >>| Option.some
         | None, Some wallet_pk -> (
             match%bind
               Secrets.Wallets.load ~logger
                 ~disk_location:wallets_disk_location
               >>| Secrets.Wallets.find ~needle:wallet_pk
             with
             | Some keypair ->
                 Deferred.Option.return keypair
             | None ->
                 eprintf
                   "Error: This public key was not found in the local \
                    daemon's wallet database" ;
                 exit 12 )
         | None, None ->
             return None
       in
       let%bind client_whitelist =
         Reader.load_sexp
           (conf_dir ^/ "client_whitelist")
           [%of_sexp: Unix.Inet_addr.Blocking_sexp.t list]
         >>| Or_error.ok
       in
       let module Config0 = struct
         let logger = logger

         let conf_dir = conf_dir

         let lbc_tree_max_depth = `Finite 50

         let propose_keypair = propose_keypair

         let genesis_proof = Precomputed_values.base_proof

         let commit_id = commit_id

         let work_selection = work_selection

         let max_concurrent_connections = max_concurrent_connections
       end in
       let%bind (module Init) = make_init (module Config0) in
       let module M = Coda_inputs.Make_coda (Init) in
       let module Run = Coda_run.Make (Config0) (M) in
       Stream.iter
         (Async.Scheduler.long_cycles
            ~at_least:(sec 0.5 |> Time_ns.Span.of_span_float_round_nearest))
         ~f:(fun span ->
           Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
             "long async cycle %s"
             (Time_ns.Span.to_string span) ) ;
       let run_snark_worker_action =
         Option.value_map run_snark_worker_flag ~default:`Don't_run
           ~f:(fun k -> `With_public_key k)
       in
       let trace_database_initialization typ location =
         Logger.trace logger "Creating %s at %s" ~module_:__MODULE__ ~location
           typ
       in
       let trust_dir = conf_dir ^/ "trust" in
       let () = Snark_params.set_chunked_hashing true in
       let%bind () = Async.Unix.mkdir ~p:() trust_dir in
       let trust_system = Trust_system.create ~db_dir:trust_dir in
       trace_database_initialization "trust_system" __LOC__ trust_dir ;
       let time_controller =
         Block_time.Controller.create Block_time.Controller.basic
       in
       let initial_propose_keypairs =
         Config0.propose_keypair |> Option.to_list |> Keypair.Set.of_list
       in
       let consensus_local_state =
         Consensus.Data.Local_state.create
           ( Option.map Config0.propose_keypair ~f:(fun keypair ->
                 let open Keypair in
                 Public_key.compress keypair.public_key )
           |> Option.to_list |> Public_key.Compressed.Set.of_list )
       in
       let net_config =
         { M.Inputs.Net.Config.logger
         ; trust_system
         ; time_controller
         ; consensus_local_state
         ; gossip_net_params=
             { timeout= Time.Span.of_sec 3.
             ; logger
             ; target_peer_count= 8
             ; conf_dir
             ; initial_peers= initial_peers_cleaned
             ; addrs_and_ports
             ; trust_system
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
         Auxiliary_database.Transaction_database.create logger
           transaction_database_dir
       in
       trace_database_initialization "transaction_database" __LOC__
         transaction_database_dir ;
       let external_transition_database_dir =
         conf_dir ^/ "external_transition_database"
       in
       let%bind () = Async.Unix.mkdir ~p:() external_transition_database_dir in
       let external_transition_database =
         Auxiliary_database.External_transition_database.create logger
           external_transition_database_dir
       in
       let monitor = Async.Monitor.create ~name:"coda" () in
       let%bind coda =
         Run.create
           (Run.Config.make ~logger ~trust_system ~verifier:Init.verifier
              ~net_config ?snark_worker_key:run_snark_worker_flag
              ~transaction_pool_disk_location:(conf_dir ^/ "transaction_pool")
              ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
              ~wallets_disk_location:(conf_dir ^/ "wallets")
              ~persistent_root_location:(conf_dir ^/ "root")
              ~persistent_frontier_location:(conf_dir ^/ "frontier")
              ~snark_work_fee:snark_work_fee_flag ~receipt_chain_database
              ~time_controller
              ~initial_propose_keypairs ~monitor ~consensus_local_state
              ~transaction_database ~external_transition_database ())
       in
       Run.handle_shutdown ~monitor ~conf_dir coda ;
       Async.Scheduler.within' ~monitor
       @@ fun () ->
       let%bind () = maybe_sleep 3. in
       M.start coda ;
       let web_service = Web_pipe.get_service () in
       Web_pipe.run_service (module Run) coda web_service ~conf_dir ~logger ;
       Run.setup_local_server ?client_whitelist ?rest_server_port ~coda
         ~client_port () ;
       Run.run_snark_worker ~client_port run_snark_worker_action ;
       Logger.info logger ~module_:__MODULE__ ~location:__LOC__
         "Running coda services" ;
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
  match%bind
    Monitor.try_with_or_error (fun () ->
        Client.get (Uri.of_string "http://updates.o1test.net/testnet_id") )
  with
  | Error e ->
      Logger.error logger ~module_:__MODULE__ ~location:__LOC__
        "exception while trying to fetch testnet_id, trying again in 6 minutes" ;
      try_later recheck_soon ;
      Deferred.unit
  | Ok (resp, body) -> (
      if resp.status <> `OK then (
        try_later recheck_soon ;
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__
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

let internal_commands = [(Snark_worker.Intf.command_name, Snark_worker.command)]

let coda_commands logger =
  [ (Parallel.worker_command_name, Parallel.worker_command)
  ; ("internal", Command.group ~summary:"Internal commands" internal_commands)
  ; ("daemon", daemon logger)
  ; ("client", Client.command)
  ; ("transaction-snark-profiler", Transaction_snark_profiler.command) ]

[%%if
integration_tests]

module type Integration_test = sig
  val name : string

  val command : Async.Command.t
end

let coda_commands logger =
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
        ; (module Coda_delegation_test)
        ; (module Full_test)
        ; (module Transaction_snark_profiler) ]
        : (module Integration_test) list )
  in
  coda_commands logger
  @ [("integration-tests", Command.group ~summary:"Integration tests" group)]

[%%endif]

let () =
  Random.self_init () ;
  let logger = Logger.create () in
  don't_wait_for (ensure_testnet_id_still_good logger) ;
  (* Turn on snark debugging in prod for now *)
  Snarky.Snark.set_eval_constraints true ;
  Command.run (Command.group ~summary:"Coda" (coda_commands logger)) ;
  Core.exit 0

[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Blockchain_snark
open Cli_lib
open Coda_main
module YJ = Yojson.Safe
module Git_sha = Client_lib.Git_sha

let commit_id = Option.map [%getenv "CODA_COMMIT_SHA1"] ~f:Git_sha.of_string

module type Coda_intf = sig
  type ledger_proof

  module Make (Init : Init_intf) () : Main_intf
end

module type Consensus_mechanism_intf = sig
  module Make (Ledger_builder_diff : sig
    type t [@@deriving bin_io, sexp]
  end) :
    Consensus.Mechanism.S
    with type Internal_transition.Ledger_builder_diff.t = Ledger_builder_diff.t
     and type External_transition.Ledger_builder_diff.t = Ledger_builder_diff.t
end

let default_external_port = 8302

let daemon (module Kernel : Kernel_intf) log =
  let open Command.Let_syntax in
  Command.async ~summary:"Coda daemon"
    (let%map_open conf_dir =
       flag "config-directory" ~doc:"DIR Configuration directory"
         (optional file)
     and should_propose_flag =
       flag "propose" ~doc:"true|false Run the proposer (default:false)"
         (optional bool)
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
              default_external_port)
         (optional int16)
     and client_port =
       flag "client-port"
         ~doc:
           (Printf.sprintf
              "PORT Client to daemon local communication (default: %d)"
              default_client_port)
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
     and proposal_interval =
       flag "proposal-interval"
         ~doc:
           "MILLIS Time between the proposer proposing and waiting (default: \
            5000)"
         (optional int)
     and is_background =
       flag "background" no_arg ~doc:"Run process on the background"
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
           Daemon.daemonize
             ~redirect_stdout:(`File_append (conf_dir ^/ "coda.stdout"))
             ~redirect_stderr:(`File_append (conf_dir ^/ "coda.stderr"))
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
           ~default:default_external_port external_port
       in
       let client_port =
         or_from_config YJ.Util.to_int_option "client-port"
           ~default:default_client_port client_port
       in
       let should_propose_flag =
         or_from_config YJ.Util.to_bool_option "propose" ~default:false
           should_propose_flag
       in
       let transaction_capacity_log_2 =
         or_from_config YJ.Util.to_int_option "txn-capacity" ~default:8
           transaction_capacity_log_2
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
       let%bind client_whitelist =
         Reader.load_sexp
           (conf_dir ^/ "client_whitelist")
           [%of_sexp: Unix.Inet_addr.Blocking_sexp.t list]
         >>| Or_error.ok
       in
       let keypair = Genesis_ledger.largest_account_keypair_exn () in
       let module Config = struct
         let logger = log

         let conf_dir = conf_dir

         let lbc_tree_max_depth = `Finite 50

         let keypair = keypair

         let genesis_proof = Precomputed_values.base_proof

         let transaction_capacity_log_2 = transaction_capacity_log_2

         let commit_id = commit_id

         let work_selection = work_selection
       end in
       let%bind (module Init) =
         make_init ~should_propose:should_propose_flag
           (module Config)
           (module Kernel)
       in
       let module M = Coda_main.Make_coda (Init) in
       let module Run = Run (Config) (M) in
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
         let banlist =
           Coda_base.Banlist.create ~suspicious_dir ~punished_dir
         in
         let net_config =
           { Inputs.Net.Config.parent_log= log
           ; gossip_net_params=
               { timeout= Time.Span.of_sec 1.
               ; parent_log= log
               ; target_peer_count= 8
               ; conf_dir
               ; initial_peers
               ; me
               ; banlist } }
         in
         let%map coda =
           Run.create
             (Run.Config.make ~log ~net_config
                ~should_propose:should_propose_flag
                ~run_snark_worker:(Option.is_some run_snark_worker_flag)
                ~ledger_builder_persistant_location:
                  (conf_dir ^/ "ledger_builder")
                ~transaction_pool_disk_location:(conf_dir ^/ "transaction_pool")
                ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
                ~time_controller:(Inputs.Time.Controller.create ())
                ~keypair () ~banlist)
         in
         let web_service = Web_pipe.get_service () in
         Web_pipe.run_service (module Run) coda web_service ~conf_dir ~log ;
         Run.setup_local_server ?client_whitelist ?rest_server_port ~coda
           ~client_port ~log () ;
         Run.run_snark_worker ~log ~client_port run_snark_worker_action
       in
       Async.never ())

let exit1 ?msg =
  match msg with
  | None -> Core.exit 1
  | Some msg ->
      Core.Printf.eprintf "%s\n" msg ;
      Core.exit 1

let env name ~f ~default =
  let name = Printf.sprintf "CODA_%s" name in
  Unix.getenv name
  |> Option.map ~f:(fun x ->
         match f @@ String.uppercase x with
         | Some v -> v
         | None ->
             exit1
               ~msg:
                 (Printf.sprintf
                    "Inside env var %s, there was a value I don't understand \
                     \"%s\""
                    name x) )
  |> Option.value ~default

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
          exit1
            ~msg:
              (sprintf
                 "The version for the testnet has changed, and this client \
                  (version %s) is no longer compatible. Please download the \
                  latest Coda software!\n\
                  Valid versions:\n\
                  %s"
                 ( local_id |> Option.map ~f:str
                 |> Option.value ~default:"[COMMIT_SHA1 not set]" )
                 remote_ids)
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

let consensus_mechanism () : (module Consensus_mechanism_intf) =
  let mechanism =
    env "CONSENSUS_MECHANISM" ~default:`Proof_of_signature ~f:(function
      | "PROOF_OF_SIGNATURE" -> Some `Proof_of_signature
      | "PROOF_OF_STAKE" -> Some `Proof_of_stake
      | _ -> None )
  in
  Core.Printf.printf
    !"consensus mechanism = %s\n%!"
    ( match mechanism with
    | `Proof_of_signature -> "PROOF_OF_SIGNATURE"
    | `Proof_of_stake -> "PROOF_OF_STAKE" ) ;
  match mechanism with
  | `Proof_of_signature ->
      ( module struct
        module Make (Ledger_builder_diff : sig
          type t [@@deriving sexp, bin_io]
        end) =
        Consensus.Proof_of_signature.Make (struct
          module Genesis_ledger = Genesis_ledger
          module Proof = Coda_base.Proof
          module Ledger_builder_diff = Ledger_builder_diff
          module Time = Coda_base.Block_time

          let private_key = Consensus.Signer_private_key.signer_private_key

          let proposal_interval =
            env "PROPOSAL_INTERVAL"
              ~default:(Time.Span.of_ms @@ Int64.of_int 5000)
              ~f:(fun str ->
                try Some (Time.Span.of_ms @@ Int64.of_string str) with _ ->
                  None )
        end)
      end )
  | `Proof_of_stake ->
      ( module struct
        module Make (Ledger_builder_diff : sig
          type t [@@deriving sexp, bin_io]
        end) =
        Consensus.Proof_of_stake.Make (struct
          module Genesis_ledger = Genesis_ledger
          module Proof = Coda_base.Proof
          module Ledger_builder_diff = Ledger_builder_diff
          module Time = Coda_base.Block_time

          (* TODO: choose reasonable values *)
          let genesis_state_timestamp =
            let default =
              Core.Time.of_date_ofday
                (Core.Time.Zone.of_utc_offset ~hours:(-7))
                (Core.Date.create_exn ~y:2018 ~m:Month.Sep ~d:1)
                (Core.Time.Ofday.create ~hr:10 ())
              |> Time.of_time
            in
            env "GENESIS_STATE_TIMESTAMP" ~default ~f:(fun str ->
                try Some (Time.of_time @@ Core.Time.of_string str) with _ ->
                  None )

          let coinbase =
            env "COINBASE" ~default:(Currency.Amount.of_int 20) ~f:(fun str ->
                try Some (Currency.Amount.of_int @@ Int.of_string str)
                with _ -> None )

          let slot_interval =
            env "SLOT_INTERVAL"
              ~default:(Time.Span.of_ms (Int64.of_int 5000))
              ~f:(fun str ->
                try Some (Time.Span.of_ms @@ Int64.of_string str) with _ ->
                  None )

          let unforkable_transition_count =
            env "UNFORKABLE_TRANSITION_COUNT" ~default:12 ~f:(fun str ->
                try Some (Int.of_string str) with _ -> None )

          let probable_slots_per_transition_count =
            env "PROBABLE_SLOTS_PER_TRANSITION_COUNT" ~default:8 ~f:(fun str ->
                try Some (Int.of_string str) with _ -> None )

          (* Conservatively pick 1seconds *)
          let expected_network_delay =
            env "EXPECTED_NETWORK_DELAY"
              ~default:(Time.Span.of_ms (Int64.of_int 1000))
              ~f:(fun str ->
                try Some (Time.Span.of_ms @@ Int64.of_string str) with _ ->
                  None )

          let approximate_network_diameter =
            env "APPROXIMATE_NETWORK_DIAMETER" ~default:3 ~f:(fun str ->
                try Some (Int.of_string str) with _ -> None )
        end)
      end )

[%%if
with_snark]

let internal_commands =
  [(Snark_worker_lib.Intf.command_name, Snark_worker_lib.Prod.Worker.command)]

[%%else]

let internal_commands =
  [(Snark_worker_lib.Intf.command_name, Snark_worker_lib.Debug.Worker.command)]

[%%endif]

let coda_commands (module Kernel : Kernel_intf) log =
  [ (Parallel.worker_command_name, Parallel.worker_command)
  ; ("internal", Command.group ~summary:"Internal commands" internal_commands)
  ; ("daemon", daemon (module Kernel) log)
  ; ("client", Client.command) ]

[%%if
integration_tests]

let coda_commands (module Kernel : Kernel_intf) log =
  let group =
    let module Coda_peers_test = Coda_peers_test.Make (Kernel) in
    let module Coda_block_production_test =
      Coda_block_production_test.Make (Kernel) in
    let module Coda_shared_prefix_test = Coda_shared_prefix_test.Make (Kernel) in
    let module Coda_restart_node_test = Coda_restart_node_test.Make (Kernel) in
    let module Coda_shared_state_test = Coda_shared_state_test.Make (Kernel) in
    let module Coda_transitive_peers_test =
      Coda_transitive_peers_test.Make (Kernel) in
    [ (Coda_peers_test.name, Coda_peers_test.command)
    ; (Coda_block_production_test.name, Coda_block_production_test.command)
    ; (Coda_shared_state_test.name, Coda_shared_state_test.command)
    ; (Coda_transitive_peers_test.name, Coda_transitive_peers_test.command)
    ; (Coda_shared_prefix_test.name, Coda_shared_prefix_test.command)
    ; (Coda_restart_node_test.name, Coda_restart_node_test.command)
    ; ("full-test", Full_test.command (module Kernel))
    ; ("transaction-snark-profiler", Transaction_snark_profiler.command) ]
  in
  coda_commands (module Kernel) log
  @ [("integration-tests", Command.group ~summary:"Integration tests" group)]

[%%endif]

let () =
  Random.self_init () ;
  let log = Logger.create () in
  don't_wait_for (ensure_testnet_id_still_good log) ;
  let (module Consensus_mechanism) = consensus_mechanism () in
  let module Kernel = Make_kernel (Consensus_mechanism.Make) in
  Command.run
    (Command.group ~summary:"Coda" (coda_commands (module Kernel) log)) ;
  Core.exit 0

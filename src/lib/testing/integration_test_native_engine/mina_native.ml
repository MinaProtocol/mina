open Core
open Async
open Signature_lib
open Integration_test_lib

(** Proof level of the build profile that this test executive resolves at
    runtime ([MINA_PROFILE], else [/etc/coda/build_config/PROFILE]). It does
    not inspect the [--mina-image] binary; [Network_manager.create] checks that
    the binary resolves the same profile. *)
let compiled_proof_level () =
  let (module G) = Genesis_constants.profiled () in
  G.proof_level

module Network_config = struct
  module Cli_inputs = Cli_inputs

  type local_config =
    { test_name : string
    ; mina_binary : string
    ; mina_archive_binary : string
    ; runtime_config : Yojson.Safe.t
    ; start_filtered_logs : string list
    ; postgres_uri : string
    }
  [@@deriving to_yojson]

  type t =
    { debug_arg : bool
    ; genesis_keypairs :
        (Network_keypair.t Core.String.Map.t
        [@to_yojson
          fun map ->
            `Assoc
              (Core.Map.fold_right ~init:[]
                 ~f:(fun ~key:k ~data:v accum ->
                   (k, Network_keypair.to_yojson v) :: accum )
                 map )] )
    ; constants : Test_config.constants
    ; local : local_config
    ; block_producers : block_producer_info list
    ; snark_coordinator : snark_coordinator_info option
    ; num_archive_nodes : int
    ; snark_worker_fee : string
    }
  [@@deriving to_yojson]

  and block_producer_info = { bp_node_name : string; bp_account_name : string }
  [@@deriving to_yojson]

  and snark_coordinator_info =
    { sc_node_name : string; sc_account_name : string; sc_worker_nodes : int }
  [@@deriving to_yojson]

  let expand ~logger ~test_name ~(cli_inputs : Cli_inputs.t) ~(debug : bool)
      ~(images : Test_config.Container_images.t) ~(test_config : Test_config.t)
      ~(constants : Test_config.constants) =
    let ({ block_producers
         ; snark_coordinator
         ; snark_worker_fee
         ; num_archive_nodes
         ; log_precomputed_blocks =
             _
             (* NOTE: log_precomputed_blocks is stored in the config but not yet
                translated into a --log-precomputed-blocks CLI argument. This is
                consistent with the Docker engine, which also stores but does not
                pass this flag to the daemon. *)
         ; start_filtered_logs
         ; _
         }
          : Test_config.t ) =
      test_config
    in
    Local_engine_common.validate_unique_node_names test_config ;
    let genesis_ledger = Genesis_ledger.create test_config.genesis_ledger in
    let test_config =
      (* Set the test's proof level to the proof level of the profile that this
         test executive resolves (dev = Check, devnet/mainnet = Full, lightnet
         = No_check). The daemons fail if the test's proof level and their own
         profile disagree. This adapts the test to the executive's profile, NOT
         to the [--mina-image] binary: the spawned daemons inherit this
         process's environment, so they normally resolve the same profile, and
         [Network_manager.create] fails early with a clear error if the binary
         resolves a different one. *)
      let compile_proof_level =
        match compiled_proof_level () with
        | Full ->
            Runtime_config.Proof_keys.Level.Full
        | Check ->
            Runtime_config.Proof_keys.Level.Check
        | No_check ->
            Runtime_config.Proof_keys.Level.No_check
      in
      { test_config with
        proof_config =
          { test_config.proof_config with level = Some compile_proof_level }
      }
    in
    let runtime_config =
      Runtime_config_builder.create ~test_config ~genesis_ledger
    in
    let genesis_constants =
      Or_error.ok_exn
        (Genesis_ledger_helper.make_genesis_constants ~logger
           ~default:constants.genesis_constants runtime_config )
    in
    let constraint_constants =
      Genesis_ledger_helper.make_constraint_constants
        ~default:constants.constraint_constants test_config.proof_config
    in
    let constants : Test_config.constants =
      { constants with genesis_constants; constraint_constants }
    in
    let block_producer_infos =
      List.map block_producers ~f:(fun node ->
          { bp_node_name = node.node_name; bp_account_name = node.account_name } )
    in
    let snark_coordinator_info =
      match snark_coordinator with
      | None ->
          None
      | Some sc ->
          Some
            { sc_node_name = sc.node_name
            ; sc_account_name = sc.account_name
            ; sc_worker_nodes = sc.worker_nodes
            }
    in
    (* Use the mina image path as the binary path for local apps.
       The user is expected to pass the path to the mina binary as --mina-image *)
    { debug_arg = debug
    ; genesis_keypairs = genesis_ledger.keypairs
    ; constants
    ; block_producers = block_producer_infos
    ; snark_coordinator = snark_coordinator_info
    ; num_archive_nodes
    ; snark_worker_fee
    ; local =
        { test_name
        ; mina_binary = images.mina
        ; mina_archive_binary = images.archive_node
        ; runtime_config = Runtime_config.to_yojson runtime_config
        ; start_filtered_logs
        ; postgres_uri = cli_inputs.postgres_uri
        }
    }
end

module Network_manager = struct
  type t =
    { logger : Logger.t
    ; test_name : string
    ; working_dir : string
    ; constants : Test_config.constants
    ; network_config : Network_config.t
    ; mutable deployed : bool
    ; genesis_keypairs : Network_keypair.t Core.String.Map.t
    ; mutable nodes : Native_network.Node.t list
    }

  let generate_random_id = Local_engine_common.generate_random_id

  let setup_working_dir ~logger ~working_dir ~(network_config : Network_config.t)
      =
    let open Deferred.Let_syntax in
    let%bind () =
      if%bind Mina_stdlib_unix.File_system.dir_exists working_dir then
        (* Only ever remove directories that live under our dedicated temp
           prefix, so a misconfigured [test_name] can never delete sibling
           directories (e.g. when run from the repo root). *)
        let temp_root = Filename.temp_dir_name in
        let safe_prefix = temp_root ^/ "mina-it" in
        if String.is_prefix working_dir ~prefix:safe_prefix then (
          [%log info] "Old working directory found; removing to start clean"
            ~metadata:
              [ ("working_dir", `String working_dir)
              ; ("safe_prefix", `String safe_prefix)
              ] ;
          Mina_stdlib_unix.File_system.remove_dir working_dir )
        else (
          [%log error] "Refusing to remove non-temporary working directory"
            ~metadata:
              [ ("working_dir", `String working_dir)
              ; ("expected_prefix", `String safe_prefix)
              ] ;
          return () )
      else return ()
    in
    [%log info] "Creating working directory %s" working_dir ;
    let%bind () = Unix.mkdir ~p:() working_dir in
    (* Write runtime config *)
    [%log info] "Writing runtime_config to %s" working_dir ;
    Yojson.Safe.to_file
      (working_dir ^/ "runtime_config.json")
      network_config.local.runtime_config
    |> Deferred.return

  let write_keys ~logger ~working_dir ~(network_config : Network_config.t) =
    let open Deferred.Let_syntax in
    let kps_base_path = working_dir ^/ "keys" in
    let%bind () = Unix.mkdir ~p:() kps_base_path in
    [%log info] "Writing genesis keys to %s" kps_base_path ;
    let%bind () =
      Deferred.List.iter (Core.String.Map.data network_config.genesis_keypairs)
        ~f:(fun kp ->
          let keypath = kps_base_path ^/ kp.keypair_name in
          Out_channel.with_file ~fail_if_exists:true keypath ~f:(fun ch ->
              kp.private_key |> Out_channel.output_string ch ) ;
          Out_channel.with_file ~fail_if_exists:true (keypath ^ ".pub")
            ~f:(fun ch -> kp.public_key |> Out_channel.output_string ch) ;
          Unix.chmod keypath ~perm:0o600 )
    in
    [%log info] "Writing seed libp2p keypair to %s" kps_base_path ;
    let keypath = kps_base_path ^/ "libp2p_key" in
    Out_channel.with_file ~fail_if_exists:true keypath ~f:(fun ch ->
        Native_node_config.Seed_config.libp2p_keypair
        |> Out_channel.output_string ch ) ;
    let%bind () = Unix.chmod keypath ~perm:0o600 in
    Unix.chmod kps_base_path ~perm:0o700

  let create_node_config_dir ~working_dir ~node_name =
    let dir = working_dir ^/ "nodes" ^/ node_name in
    dir

  (* The test's proof level comes from the profile that this test executive
     resolves (see [compiled_proof_level]). Check that the target [mina] binary
     resolves the same profile, so that a mismatch fails here with a clear
     error instead of a daemon crash later. The binary does not print its
     profile name or proof level, so compare consensus constants that are
     different in each profile. [MINA_CONFIG_FILE] points at a file that does
     not exist, so the binary reports its profile defaults and does not read a
     daemon.json from the home directory. *)
  let check_binary_profile ~logger ~working_dir ~mina_binary =
    let open Malleable_error.Let_syntax in
    let (module G) = Genesis_constants.profiled () in
    let expected =
      [ ("k", G.genesis_constants.protocol.k)
      ; ("slots_per_epoch", G.genesis_constants.protocol.slots_per_epoch)
      ; ( "block_window_duration_ms"
        , G.constraint_constants.block_window_duration_ms )
      ]
    in
    let%bind output =
      Util.run_cmd_or_hard_error
        ~env:
          (`Extend
            [ ("MINA_CONFIG_FILE", working_dir ^/ "no-such-daemon-config.json")
            ] )
        working_dir mina_binary
        [ "advanced"; "compile-time-constants" ]
    in
    let%bind actual =
      match
        Or_error.try_with (fun () ->
            let json =
              String.split_lines output
              |> List.filter ~f:(Fn.non String.is_empty)
              |> List.last_exn |> Yojson.Safe.from_string
            in
            List.map expected ~f:(fun (key, _) ->
                (key, Yojson.Safe.Util.(member key json |> to_int)) ) )
      with
      | Ok actual ->
          return actual
      | Error err ->
          Malleable_error.hard_error_format
            "Cannot read the compile-time constants of %s: %s" mina_binary
            (Error.to_string_hum err)
    in
    if
      List.equal (Tuple2.equal ~eq1:String.equal ~eq2:Int.equal) expected actual
    then (
      [%log info] "Binary %s resolves the same profile as the test executive"
        mina_binary ;
      return () )
    else
      let show l =
        String.concat ~sep:", "
          (List.map l ~f:(fun (key, value) -> sprintf "%s=%d" key value))
      in
      Malleable_error.hard_error_format
        "Profile mismatch: %s resolves a different profile than the test \
         executive (binary: %s; test executive: %s). Set MINA_PROFILE so that \
         both resolve the same profile."
        mina_binary (show actual) (show expected)

  let create ~logger (network_config : Network_config.t) =
    let open Malleable_error.Let_syntax in
    (* Place all per-test working directories under a dedicated temp root
       ([<tmp>/mina-it/<test_name>]). This keeps removals scoped to a safe
       prefix, and the directories of different tests do not collide. The
       leaf name is sanitised so an absolute or nested [test_name] cannot
       escape the temp root. This does not make concurrent runs on one host
       safe: two runs of the same test share a directory, and node ports are
       only probed when allocated (see [Native_node_config.PortManager]), so
       two runs can still race for a port. Concurrent runs on one host are not
       supported. *)
    let temp_root = Filename.temp_dir_name in
    let safe_test_name = Filename.basename network_config.local.test_name in
    let working_dir = temp_root ^/ "mina-it" ^/ safe_test_name in
    let%bind.Deferred () =
      setup_working_dir ~logger ~working_dir ~network_config
    in
    let%bind.Deferred () = write_keys ~logger ~working_dir ~network_config in
    let%bind () =
      check_binary_profile ~logger ~working_dir
        ~mina_binary:network_config.local.mina_binary
    in
    let t =
      { logger
      ; test_name = network_config.local.test_name
      ; working_dir
      ; constants = network_config.constants
      ; network_config
      ; deployed = false
      ; genesis_keypairs = network_config.genesis_keypairs
      ; nodes = []
      }
    in
    Malleable_error.return t

  let build_node_config ~working_dir ~service_name ~node_type ~ports
      ~(base_config : Native_node_config.Base_node_config.t) ~extra_args
      ~mina_binary ~network_keypair ~postgres_connection_uri =
    let config_dir =
      create_node_config_dir ~working_dir ~node_name:service_name
    in
    let libp2p_key_path =
      match node_type with
      | Native_network.Node.Seed ->
          (* Seed nodes use the hardcoded libp2p keypair *)
          working_dir ^/ "keys" ^/ "libp2p_key"
      | _ ->
          (* Non-seed nodes get their own libp2p key, generated at start *)
          config_dir ^/ "libp2p_key"
    in
    let base_cmd_args =
      Native_node_config.Base_node_config.to_cmd_args base_config ~ports
        ~libp2p_key_path
    in
    let config_dir_args =
      [ "--config-directory"; config_dir ^/ ".mina-config" ]
    in
    let cmd_args = List.concat [ extra_args; base_cmd_args; config_dir_args ] in
    let log_file = working_dir ^/ service_name ^ ".log" in
    let runtime_config_path = base_config.runtime_config_path in
    { Native_network.Node.config =
        { network_keypair
        ; service_name
        ; postgres_connection_uri
        ; graphql_port = ports.rest_port
        ; ports
        ; config_dir
        ; libp2p_key_path
        ; runtime_config_path
        ; node_type
        ; cmd_args
        ; mina_binary
        }
    ; started = false
    ; should_be_running = false
    ; process = None
    ; log_file
    }

  let archive_cmd_args ~postgres_connection_uri ~server_port
      ~runtime_config_path =
    "run"
    :: Mina_automation_args.Archive_args.to_list
         { (Mina_automation_args.Archive_args.create
              ~postgres_uri:postgres_connection_uri ~server_port )
           with
           config_file = runtime_config_path
         }

  let%test_unit "archive_cmd_args keeps the archive arguments" =
    let actual =
      archive_cmd_args ~postgres_connection_uri:"postgres://db"
        ~server_port:3086 ~runtime_config_path:(Some "/cfg.json")
    in
    let expected =
      [ "run"
      ; "-postgres-uri"
      ; "postgres://db"
      ; "-server-port"
      ; "3086"
      ; "-config-file"
      ; "/cfg.json"
      ]
    in
    if not (List.equal String.equal actual expected) then
      failwithf "unexpected archive args: %s" (String.concat ~sep:" " actual) ()

  (* Archive nodes run the [mina-archive] binary, whose CLI does NOT accept the
     daemon's flags (client/rest/external/metrics ports, libp2p keypair, etc.). *)
  let build_archive_node_config ~working_dir ~service_name ~ports
      ~runtime_config_path ~mina_archive_binary ~postgres_connection_uri
      ~server_port =
    let config_dir =
      create_node_config_dir ~working_dir ~node_name:service_name
    in
    let libp2p_key_path = config_dir ^/ "libp2p_key" in
    let cmd_args =
      archive_cmd_args ~postgres_connection_uri ~server_port
        ~runtime_config_path
    in
    let log_file = working_dir ^/ service_name ^ ".log" in
    { Native_network.Node.config =
        { network_keypair = None
        ; service_name
        ; postgres_connection_uri = Some postgres_connection_uri
        ; graphql_port = ports.Native_node_config.Node_ports.rest_port
        ; ports
        ; config_dir
        ; libp2p_key_path
        ; runtime_config_path
        ; node_type = Native_network.Node.Archive
        ; cmd_args
        ; mina_binary = mina_archive_binary
        }
    ; started = false
    ; should_be_running = false
    ; process = None
    ; log_file
    }

  let deploy t =
    let logger = t.logger in
    if t.deployed then failwith "network already deployed" ;
    let network_config = t.network_config in
    let working_dir = t.working_dir in
    let runtime_config_path = working_dir ^/ "runtime_config.json" in
    let port_manager =
      Native_node_config.PortManager.create ~min_port:11000 ~max_port:12000
    in
    let seed_ports =
      Native_node_config.PortManager.allocate_ports_for_node port_manager
    in
    (* Pre-compute all node names so we can create directories first *)
    let seed_name = sprintf "seed-%s" (generate_random_id ()) in
    let archive_seed_names =
      List.init network_config.num_archive_nodes ~f:(fun index ->
          sprintf "seed-%d-%s" (index + 1) (generate_random_id ()) )
    in
    let archive_node_names =
      List.init network_config.num_archive_nodes ~f:(fun index ->
          sprintf "archive-%d-%s" (index + 1) (generate_random_id ()) )
    in
    let bp_node_names =
      List.map network_config.block_producers ~f:(fun bp -> bp.bp_node_name)
    in
    let sc_node_name =
      Option.map network_config.snark_coordinator ~f:(fun sc ->
          sc.sc_node_name )
    in
    let snark_worker_names =
      match network_config.snark_coordinator with
      | None ->
          []
      | Some sc ->
          List.init sc.sc_worker_nodes ~f:(fun index ->
              sprintf "snark-worker-%d-%s" (index + 1) (generate_random_id ()) )
    in
    let all_node_names =
      [ seed_name ] @ archive_seed_names @ archive_node_names @ bp_node_names
      @ Option.to_list sc_node_name
      @ snark_worker_names
    in
    (* Create all node directories upfront. The per-node directory holds the
       node's generated libp2p keypair, and the daemon refuses to load that key
       unless its containing directory is mode 0700 (it rejects group/other
       permissions as insecure). Create them with restrictive permissions so
       non-seed nodes can start. *)
    let%bind.Deferred () = Unix.mkdir ~p:() (working_dir ^/ "nodes") in
    let%bind.Deferred () =
      Deferred.List.iter all_node_names ~f:(fun name ->
          Unix.mkdir ~perm:0o700
            (create_node_config_dir ~working_dir ~node_name:name) )
    in
    (* Build seed node *)
    let seed_base_config =
      Native_node_config.Base_node_config.default ~peer:None
        ~runtime_config_path:(Some runtime_config_path)
        ~start_filtered_logs:network_config.local.start_filtered_logs ()
    in
    let seed_node =
      build_node_config ~working_dir ~service_name:seed_name
        ~node_type:Native_network.Node.Seed ~ports:seed_ports
        ~base_config:seed_base_config ~extra_args:[ "daemon"; "-seed" ]
        ~mina_binary:network_config.local.mina_binary ~network_keypair:None
        ~postgres_connection_uri:None
    in
    let seed_peer =
      Native_node_config.Seed_config.create_libp2p_peer
        ~external_port:seed_ports.external_port
    in
    (* Build archive seed nodes (one per archive node) *)
    let archive_seed_nodes =
      List.map archive_seed_names ~f:(fun name ->
          let ports =
            Native_node_config.PortManager.allocate_ports_for_node port_manager
          in
          let archive_server_port =
            Native_node_config.PortManager.allocate_port port_manager
          in
          let archive_address = sprintf "127.0.0.1:%d" archive_server_port in
          let base_config =
            Native_node_config.Base_node_config.default ~peer:(Some seed_peer)
              ~runtime_config_path:(Some runtime_config_path)
              ~start_filtered_logs:network_config.local.start_filtered_logs ()
          in
          let node =
            build_node_config ~working_dir ~service_name:name
              ~node_type:Native_network.Node.Seed ~ports ~base_config
              ~extra_args:
                [ "daemon"; "-seed"; "-archive-address"; archive_address ]
              ~mina_binary:network_config.local.mina_binary
              ~network_keypair:None ~postgres_connection_uri:None
          in
          (node, archive_server_port) )
    in
    let seed_nodes = List.map archive_seed_nodes ~f:fst @ [ seed_node ] in
    let seeds =
      List.map seed_nodes ~f:(fun node -> (Native_network.Node.id node, node))
      |> Core.String.Map.of_alist_exn
    in
    (* Build archive nodes.
       Archive nodes require a running PostgreSQL server, reachable at
       [network_config.local.postgres_uri]. Each archive node gets its own
       per-test database on that server, which the node creates and loads the
       archive schema into on start, and drops on stop (see
       [Native_network.Node]). The name is [test_archive_<pid>_<id>], where
       [<pid>] is this test executive's process id, so that the databases of
       a run that was killed before its nodes stopped can be found and
       dropped by hand ([test_archive_<pid>_%]). *)
    let archive_nodes =
      List.mapi archive_seed_nodes
        ~f:(fun index (_seed_node, archive_server_port) ->
          let name = List.nth_exn archive_node_names index in
          let ports =
            Native_node_config.PortManager.allocate_ports_for_node port_manager
          in
          let db_name =
            sprintf "test_archive_%s_%s"
              (Pid.to_string (Unix.getpid ()))
              (generate_random_id ())
          in
          let postgres_connection_uri =
            Uri.with_path
              (Uri.of_string network_config.local.postgres_uri)
              ("/" ^ db_name)
            |> Uri.to_string
          in
          let node =
            build_archive_node_config ~working_dir ~service_name:name ~ports
              ~runtime_config_path:(Some runtime_config_path)
              ~mina_archive_binary:network_config.local.mina_archive_binary
              ~postgres_connection_uri ~server_port:archive_server_port
          in
          (Native_network.Node.id node, node) )
      |> Core.String.Map.of_alist_exn
    in
    (* Build block producer nodes *)
    let block_producers =
      List.map network_config.block_producers ~f:(fun bp_info ->
          let keypair =
            Local_engine_common.find_genesis_keypair_exn
              network_config.genesis_keypairs ~role:"block producers"
              ~node_name:bp_info.bp_node_name
              ~account_name:bp_info.bp_account_name
          in
          let priv_key_path =
            working_dir ^/ "keys" ^/ bp_info.bp_account_name
          in
          let ports =
            Native_node_config.PortManager.allocate_ports_for_node port_manager
          in
          let base_config =
            Native_node_config.Base_node_config.default ~peer:(Some seed_peer)
              ~runtime_config_path:(Some runtime_config_path)
              ~start_filtered_logs:network_config.local.start_filtered_logs ()
          in
          let node =
            build_node_config ~working_dir ~service_name:bp_info.bp_node_name
              ~node_type:Native_network.Node.Block_producer ~ports ~base_config
              ~extra_args:
                [ "daemon"
                ; "-block-producer-key"
                ; priv_key_path
                ; "-enable-flooding"
                ; "true"
                ; "-enable-peer-exchange"
                ; "true"
                ]
              ~mina_binary:network_config.local.mina_binary
              ~network_keypair:(Some keypair) ~postgres_connection_uri:None
          in
          (bp_info.bp_node_name, node) )
      |> Core.String.Map.of_alist_exn
    in
    (* Build snark coordinator and worker nodes *)
    let snark_coordinators, snark_workers =
      match network_config.snark_coordinator with
      | None ->
          (Core.String.Map.empty, Core.String.Map.empty)
      | Some sc_info ->
          let network_kp =
            Local_engine_common.find_genesis_keypair_exn
              network_config.genesis_keypairs ~role:"snark coordinators"
              ~node_name:sc_info.sc_node_name
              ~account_name:sc_info.sc_account_name
          in
          let public_key =
            Public_key.Compressed.to_base58_check
              (Public_key.compress network_kp.keypair.public_key)
          in
          let coordinator_ports =
            Native_node_config.PortManager.allocate_ports_for_node port_manager
          in
          let base_config =
            Native_node_config.Base_node_config.default ~peer:(Some seed_peer)
              ~runtime_config_path:(Some runtime_config_path)
              ~start_filtered_logs:network_config.local.start_filtered_logs ()
          in
          let coordinator_node =
            build_node_config ~working_dir ~service_name:sc_info.sc_node_name
              ~node_type:Native_network.Node.Snark_coordinator
              ~ports:coordinator_ports ~base_config
              ~extra_args:
                [ "daemon"
                ; "-run-snark-coordinator"
                ; public_key
                ; "-snark-worker-fee"
                ; network_config.snark_worker_fee
                ; "-work-selection"
                ; "seq"
                ]
              ~mina_binary:network_config.local.mina_binary
              ~network_keypair:None ~postgres_connection_uri:None
          in
          let coordinator_map =
            Core.String.Map.of_alist_exn
              [ (sc_info.sc_node_name, coordinator_node) ]
          in
          let worker_map =
            List.mapi snark_worker_names ~f:(fun _index name ->
                let ports =
                  Native_node_config.PortManager.allocate_ports_for_node
                    port_manager
                in
                let worker_base_config =
                  Native_node_config.Base_node_config.default ~peer:None
                    ~runtime_config_path:None ~start_filtered_logs:[] ()
                in
                let node =
                  build_node_config ~working_dir ~service_name:name
                    ~node_type:Native_network.Node.Snark_worker ~ports
                    ~base_config:worker_base_config
                    ~extra_args:
                      [ "internal"
                      ; "snark-worker"
                      ; "-proof-level"
                      ; Genesis_constants.Proof_level.to_string
                          (compiled_proof_level ())
                      ; "-daemon-address"
                      ; sprintf "127.0.0.1:%d" coordinator_ports.client_port
                      ; "--shutdown-on-disconnect"
                      ; "false"
                      ]
                    ~mina_binary:network_config.local.mina_binary
                    ~network_keypair:None ~postgres_connection_uri:None
                in
                (name, node) )
            |> Core.String.Map.of_alist_exn
          in
          (coordinator_map, worker_map)
    in
    t.deployed <- true ;
    let nodes_to_string =
      Fn.compose (String.concat ~sep:", ") (List.map ~f:Native_network.Node.id)
    in
    let network =
      { Native_network.namespace = t.test_name
      ; constants = t.constants
      ; seeds
      ; block_producers
      ; snark_coordinators
      ; snark_workers
      ; archive_nodes
      ; genesis_keypairs = t.genesis_keypairs
      }
    in
    (* Store all nodes for cleanup in destroy *)
    let all_node_list =
      List.concat
        [ Core.String.Map.data seeds
        ; Core.String.Map.data block_producers
        ; Core.String.Map.data snark_coordinators
        ; Core.String.Map.data snark_workers
        ; Core.String.Map.data archive_nodes
        ]
    in
    t.nodes <- all_node_list ;
    [%log info] "Network configured (local apps engine)" ;
    [%log info] "testnet namespace: %s" t.test_name ;
    [%log info] "seeds: %s"
      (nodes_to_string (Core.String.Map.data network.seeds)) ;
    [%log info] "block producers: %s"
      (nodes_to_string (Core.String.Map.data network.block_producers)) ;
    [%log info] "snark coordinators: %s"
      (nodes_to_string (Core.String.Map.data network.snark_coordinators)) ;
    [%log info] "snark workers: %s"
      (nodes_to_string (Core.String.Map.data network.snark_workers)) ;
    [%log info] "archive nodes: %s"
      (nodes_to_string (Core.String.Map.data network.archive_nodes)) ;
    Malleable_error.return network

  let destroy_deferred t =
    let logger = t.logger in
    [%log info] "Destroying local apps network" ;
    if not t.deployed then failwith "network not deployed" ;
    (* Stop all running node processes *)
    let%bind.Deferred () =
      Deferred.List.iter t.nodes ~f:(fun node ->
          [%log info] "Stopping node %s" (Native_network.Node.id node) ;
          let%map.Deferred _ = Native_network.Node.stop node in
          () )
    in
    t.nodes <- [] ;
    t.deployed <- false ;
    Deferred.unit

  let cleanup t =
    let logger = t.logger in
    (* Capture the node list before [destroy] clears it, so we can preserve the
       per-node logs below. *)
    let nodes = t.nodes in
    let%bind () = if t.deployed then destroy_deferred t else return () in
    (* Copy each node's logs into the current working directory, as
       [<test>-<node>*.native.test.log], before deleting the (temporary)
       working dir. We preserve the node's own
       stdout/stderr as well as the prover/verifier subprocess logs, since a
       node that fails to initialise usually does so because one of those
       subprocesses died. Without this the logs are lost on teardown and a
       failing node can't be diagnosed. *)
    let copy_log ~src ~dest =
      match%map.Deferred
        Monitor.try_with ~here:[%here] (fun () ->
            let%bind.Deferred contents = Reader.file_contents src in
            Writer.save dest ~contents )
      with
      | Ok () ->
          ()
      | Error _ ->
          ()
    in
    let%bind () =
      Deferred.List.iter nodes ~f:(fun node ->
          let name = Native_network.Node.id node in
          let mina_config =
            node.Native_network.Node.config.config_dir ^/ ".mina-config"
          in
          let logs =
            [ (node.Native_network.Node.log_file, "")
            ; (mina_config ^/ "mina-prover.log", "-prover")
            ; (mina_config ^/ "mina-verifier.log", "-verifier")
            ]
          in
          Deferred.List.iter logs ~f:(fun (src, suffix) ->
              let dest =
                sprintf "%s-%s%s.native.test.log" t.test_name name suffix
              in
              copy_log ~src ~dest ) )
    in
    [%log info] "Cleaning up network configuration" ;
    let%bind () =
      match%bind
        Monitor.try_with ~here:[%here] (fun () ->
            Mina_stdlib_unix.File_system.remove_dir t.working_dir )
      with
      | Ok () ->
          Deferred.unit
      | Error _ ->
          Deferred.unit
    in
    Deferred.unit

  let destroy t =
    Deferred.Or_error.try_with ~here:[%here] (fun () -> destroy_deferred t)
    |> Deferred.bind ~f:Malleable_error.or_hard_error
end

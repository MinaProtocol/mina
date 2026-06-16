open Core
open Async
open Signature_lib
open Integration_test_lib

module Network_config = struct
  module Cli_inputs = Cli_inputs

  type local_config =
    { test_name : string
    ; mina_binary : string
    ; mina_archive_binary : string
    ; runtime_config : Yojson.Safe.t
    ; seed_peer_address : string option
    ; seed_external_port : int
    ; log_precomputed_blocks : bool
    ; start_filtered_logs : string list
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
    let _ = cli_inputs in
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
    let all_nodes_names_list =
      List.map block_producers ~f:(fun acct -> acct.node_name)
      @ match snark_coordinator with None -> [] | Some n -> [ n.node_name ]
    in
    if List.contains_dup ~compare:String.compare all_nodes_names_list then
      failwith
        "All nodes in testnet must have unique names.  Check to make sure you \
         are not using the same node_name more than once" ;
    let genesis_ledger = Genesis_ledger.create test_config.genesis_ledger in
    let test_config =
      (* Override proof level to match the compile-time proof level of the
         binary, so that local-apps tests work with any build profile *)
      let compile_proof_level =
        match Genesis_constants.Compiled.proof_level with
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
    (* Port allocation happens in deploy; use placeholders here *)
    let seed_peer_address = None in
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
        ; seed_peer_address
        ; seed_external_port = 0
        ; log_precomputed_blocks = test_config.log_precomputed_blocks
        ; start_filtered_logs
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
    ; mutable nodes : Local_network.Node.t list
    }

  let generate_random_id () =
    let rand_char () =
      let ascii_a = int_of_char 'a' in
      let ascii_z = int_of_char 'z' in
      char_of_int (ascii_a + Random.int (ascii_z - ascii_a + 1))
    in
    String.init 4 ~f:(fun _ -> rand_char ())

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
          let%bind _ =
            Util.run_cmd_exn kps_base_path "chmod" [ "600"; kp.keypair_name ]
          in
          Deferred.unit )
    in
    [%log info] "Writing seed libp2p keypair to %s" kps_base_path ;
    let keypath = kps_base_path ^/ "libp2p_key" in
    Out_channel.with_file ~fail_if_exists:true keypath ~f:(fun ch ->
        Local_node_config.Seed_config.libp2p_keypair
        |> Out_channel.output_string ch ) ;
    let%bind _ =
      Util.run_cmd_exn kps_base_path "chmod" [ "600"; "libp2p_key" ]
    in
    let%bind _ = Util.run_cmd_exn working_dir "chmod" [ "700"; "keys" ] in
    return ()

  let create_node_config_dir ~working_dir ~node_name =
    let dir = working_dir ^/ "nodes" ^/ node_name in
    dir

  let create ~logger (network_config : Network_config.t) =
    (* Place all per-test working directories under a dedicated temp root
       ([<tmp>/mina-it/<test_name>]). This keeps removals scoped to a safe
       prefix and lets concurrent runs of different tests coexist. The leaf
       name is sanitised so an absolute or nested [test_name] cannot escape
       the temp root. *)
    let temp_root = Filename.temp_dir_name in
    let safe_test_name = Filename.basename network_config.local.test_name in
    let working_dir = temp_root ^/ "mina-it" ^/ safe_test_name in
    let%bind.Deferred () =
      setup_working_dir ~logger ~working_dir ~network_config
    in
    let%bind.Deferred () = write_keys ~logger ~working_dir ~network_config in
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
      ~(base_config : Local_node_config.Base_node_config.t) ~extra_args
      ~mina_binary ~network_keypair ~postgres_connection_uri =
    let config_dir =
      create_node_config_dir ~working_dir ~node_name:service_name
    in
    let libp2p_key_path =
      match node_type with
      | Local_network.Node.Seed ->
          (* Seed nodes use the hardcoded libp2p keypair *)
          working_dir ^/ "keys" ^/ "libp2p_key"
      | _ ->
          (* Non-seed nodes get their own libp2p key, generated at start *)
          config_dir ^/ "libp2p_key"
    in
    let base_cmd_args =
      Local_node_config.Base_node_config.to_cmd_args base_config ~ports
        ~libp2p_key_path
    in
    let config_dir_args =
      [ "--config-directory"; config_dir ^/ ".mina-config" ]
    in
    let cmd_args = List.concat [ extra_args; base_cmd_args; config_dir_args ] in
    let log_file = working_dir ^/ service_name ^ ".log" in
    let runtime_config_path = base_config.runtime_config_path in
    { Local_network.Node.config =
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
    ; should_be_running = false
    ; process = None
    ; log_file
    }

  (* Archive nodes run the [mina-archive] binary, whose CLI does NOT accept the
     daemon's flags (client/rest/external/metrics ports, libp2p keypair, etc.).
     Build the command line directly here, mirroring
     [integration_test_local_engine]'s [Archive_node_config.create_cmd]:
     [mina-archive run -postgres-uri ... -server-port ...] plus an optional
     [-config-file]. *)
  let build_archive_node_config ~working_dir ~service_name ~ports
      ~runtime_config_path ~mina_archive_binary ~postgres_connection_uri
      ~server_port =
    let config_dir =
      create_node_config_dir ~working_dir ~node_name:service_name
    in
    let libp2p_key_path = config_dir ^/ "libp2p_key" in
    let base_args =
      [ "run"
      ; "-postgres-uri"
      ; postgres_connection_uri
      ; "-server-port"
      ; Int.to_string server_port
      ]
    in
    let config_file_args =
      match runtime_config_path with
      | Some path ->
          [ "-config-file"; path ]
      | None ->
          []
    in
    let cmd_args = List.concat [ base_args; config_file_args ] in
    let log_file = working_dir ^/ service_name ^ ".log" in
    { Local_network.Node.config =
        { network_keypair = None
        ; service_name
        ; postgres_connection_uri = Some postgres_connection_uri
        ; graphql_port = ports.Local_node_config.Node_ports.rest_port
        ; ports
        ; config_dir
        ; libp2p_key_path
        ; runtime_config_path
        ; node_type = Local_network.Node.Archive
        ; cmd_args
        ; mina_binary = mina_archive_binary
        }
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
      Local_node_config.PortManager.create ~min_port:11000 ~max_port:12000
    in
    let seed_ports =
      Local_node_config.PortManager.allocate_ports_for_node port_manager
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
      Local_node_config.Base_node_config.default ~peer:None
        ~runtime_config_path:(Some runtime_config_path)
        ~start_filtered_logs:network_config.local.start_filtered_logs
    in
    let seed_node =
      build_node_config ~working_dir ~service_name:seed_name
        ~node_type:Local_network.Node.Seed ~ports:seed_ports
        ~base_config:seed_base_config ~extra_args:[ "daemon"; "-seed" ]
        ~mina_binary:network_config.local.mina_binary ~network_keypair:None
        ~postgres_connection_uri:None
    in
    let seed_peer =
      Local_node_config.Seed_config.create_libp2p_peer
        ~external_port:seed_ports.external_port
    in
    (* Build archive seed nodes (one per archive node) *)
    let archive_seed_nodes =
      List.map archive_seed_names ~f:(fun name ->
          let ports =
            Local_node_config.PortManager.allocate_ports_for_node port_manager
          in
          let archive_server_port =
            Local_node_config.PortManager.allocate_port port_manager
          in
          let archive_address = sprintf "127.0.0.1:%d" archive_server_port in
          let base_config =
            Local_node_config.Base_node_config.default ~peer:(Some seed_peer)
              ~runtime_config_path:(Some runtime_config_path)
              ~start_filtered_logs:network_config.local.start_filtered_logs
          in
          let node =
            build_node_config ~working_dir ~service_name:name
              ~node_type:Local_network.Node.Seed ~ports ~base_config
              ~extra_args:
                [ "daemon"; "-seed"; "-archive-address"; archive_address ]
              ~mina_binary:network_config.local.mina_binary
              ~network_keypair:None ~postgres_connection_uri:None
          in
          (node, archive_server_port) )
    in
    let seed_nodes = List.map archive_seed_nodes ~f:fst @ [ seed_node ] in
    let seeds =
      List.map seed_nodes ~f:(fun node -> (Local_network.Node.id node, node))
      |> Core.String.Map.of_alist_exn
    in
    (* Build archive nodes.
       NOTE: Archive nodes require an externally running PostgreSQL instance.
       The archive process will fail to start if PostgreSQL is not available
       at the configured postgres_connection_uri. *)
    let archive_nodes =
      List.mapi archive_seed_nodes
        ~f:(fun index (_seed_node, archive_server_port) ->
          let name = List.nth_exn archive_node_names index in
          let ports =
            Local_node_config.PortManager.allocate_ports_for_node port_manager
          in
          let postgres_port =
            Local_node_config.PortManager.allocate_port port_manager
          in
          let postgres_connection_uri =
            sprintf "postgres://postgres:password@127.0.0.1:%d/archive"
              postgres_port
          in
          let node =
            build_archive_node_config ~working_dir ~service_name:name ~ports
              ~runtime_config_path:(Some runtime_config_path)
              ~mina_archive_binary:network_config.local.mina_archive_binary
              ~postgres_connection_uri ~server_port:archive_server_port
          in
          (Local_network.Node.id node, node) )
      |> Core.String.Map.of_alist_exn
    in
    (* Build block producer nodes *)
    let block_producers =
      List.map network_config.block_producers ~f:(fun bp_info ->
          let keypair =
            match
              Core.String.Map.find network_config.genesis_keypairs
                bp_info.bp_account_name
            with
            | Some keypair ->
                keypair
            | None ->
                let failstring =
                  Format.sprintf
                    "Failing because the account key of all initial block \
                     producers must be in the genesis ledger.  name of Node: \
                     %s.  name of Account which does not exist: %s"
                    bp_info.bp_node_name bp_info.bp_account_name
                in
                failwith failstring
          in
          let priv_key_path =
            working_dir ^/ "keys" ^/ bp_info.bp_account_name
          in
          let ports =
            Local_node_config.PortManager.allocate_ports_for_node port_manager
          in
          let base_config =
            Local_node_config.Base_node_config.default ~peer:(Some seed_peer)
              ~runtime_config_path:(Some runtime_config_path)
              ~start_filtered_logs:network_config.local.start_filtered_logs
          in
          let node =
            build_node_config ~working_dir ~service_name:bp_info.bp_node_name
              ~node_type:Local_network.Node.Block_producer ~ports ~base_config
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
            match
              Core.String.Map.find network_config.genesis_keypairs
                sc_info.sc_account_name
            with
            | Some acct ->
                acct
            | None ->
                let failstring =
                  Format.sprintf
                    "Failing because the account key of all initial snark \
                     coordinators must be in the genesis ledger.  name of \
                     Node: %s.  name of Account which does not exist: %s"
                    sc_info.sc_node_name sc_info.sc_account_name
                in
                failwith failstring
          in
          let public_key =
            Public_key.Compressed.to_base58_check
              (Public_key.compress network_kp.keypair.public_key)
          in
          let coordinator_ports =
            Local_node_config.PortManager.allocate_ports_for_node port_manager
          in
          let base_config =
            Local_node_config.Base_node_config.default ~peer:(Some seed_peer)
              ~runtime_config_path:(Some runtime_config_path)
              ~start_filtered_logs:network_config.local.start_filtered_logs
          in
          let coordinator_node =
            build_node_config ~working_dir ~service_name:sc_info.sc_node_name
              ~node_type:Local_network.Node.Snark_coordinator
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
                  Local_node_config.PortManager.allocate_ports_for_node
                    port_manager
                in
                let worker_base_config =
                  Local_node_config.Base_node_config.default ~peer:None
                    ~runtime_config_path:None ~start_filtered_logs:[]
                in
                let node =
                  build_node_config ~working_dir ~service_name:name
                    ~node_type:Local_network.Node.Snark_worker ~ports
                    ~base_config:worker_base_config
                    ~extra_args:
                      [ "internal"
                      ; "snark-worker"
                      ; "-proof-level"
                      ; Genesis_constants.Proof_level.to_string
                          Genesis_constants.Compiled.proof_level
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
      Fn.compose (String.concat ~sep:", ") (List.map ~f:Local_network.Node.id)
    in
    let network =
      { Local_network.namespace = t.test_name
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

  let destroy t =
    let logger = t.logger in
    [%log info] "Destroying local apps network" ;
    if not t.deployed then failwith "network not deployed" ;
    (* Stop all running node processes *)
    let%bind.Deferred () =
      Deferred.List.iter t.nodes ~f:(fun node ->
          [%log info] "Stopping node %s" (Local_network.Node.id node) ;
          let%map.Deferred _ = Local_network.Node.stop node in
          () )
    in
    t.nodes <- [] ;
    t.deployed <- false ;
    Deferred.unit

  let cleanup t =
    let logger = t.logger in
    let%bind () = if t.deployed then destroy t else return () in
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
    Deferred.Or_error.try_with ~here:[%here] (fun () -> destroy t)
    |> Deferred.bind ~f:Malleable_error.or_hard_error
end

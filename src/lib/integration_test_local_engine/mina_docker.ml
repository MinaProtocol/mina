open Core
open Async
open Currency
open Signature_lib
open Mina_base
open Integration_test_lib

let docker_swarm_version = "3.8"

module Network_config = struct
  module Cli_inputs = Cli_inputs

  type docker_config =
    { docker_swarm_version : string
    ; stack_name : string
    ; mina_image : string
    ; mina_agent_image : string
    ; mina_bots_image : string
    ; mina_points_image : string
    ; mina_archive_image : string
    ; runtime_config : Yojson.Safe.t
    ; seed_configs : Docker_node_config.Seed_config.t list
    ; block_producer_configs : Docker_node_config.Block_producer_config.t list
    ; snark_coordinator_config :
        Docker_node_config.Snark_coordinator_config.t option
    ; archive_node_configs : Docker_node_config.Archive_node_config.t list
    ; mina_archive_schema_aux_files : string list
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
    ; docker : docker_config
    }
  [@@deriving to_yojson]

  let expand ~logger ~test_name ~(cli_inputs : Cli_inputs.t) ~(debug : bool)
      ~(test_config : Test_config.t) ~(images : Test_config.Container_images.t)
      =
    let _ = cli_inputs in
    let ({ genesis_ledger
         ; epoch_data
         ; block_producers
         ; snark_coordinator
         ; snark_worker_fee
         ; num_archive_nodes
         ; log_precomputed_blocks (* ; num_plain_nodes *)
         ; start_filtered_logs
         ; proof_config
         ; k
         ; delta
         ; slots_per_epoch
         ; slots_per_sub_window
         ; grace_period_slots
         ; txpool_max_size
         ; slot_tx_end
         ; slot_chain_end
         ; _
         }
          : Test_config.t ) =
      test_config
    in
    let git_commit = Mina_version.commit_id_short in
    let stack_name = "it-" ^ git_commit ^ "-" ^ test_name in
    let key_names_list =
      List.map genesis_ledger ~f:(fun acct -> acct.account_name)
    in
    if List.contains_dup ~compare:String.compare key_names_list then
      failwith
        "All accounts in genesis ledger must have unique names.  Check to make \
         sure you are not using the same account_name more than once" ;
    let all_nodes_names_list =
      List.map block_producers ~f:(fun acct -> acct.node_name)
      @ match snark_coordinator with None -> [] | Some n -> [ n.node_name ]
    in
    if List.contains_dup ~compare:String.compare all_nodes_names_list then
      failwith
        "All nodes in testnet must have unique names.  Check to make sure you \
         are not using the same node_name more than once" ;
    let keypairs =
      List.take
        (List.tl_exn
           (Array.to_list (Lazy.force Key_gen.Sample_keypairs.keypairs)) )
        (List.length genesis_ledger)
    in
    let runtime_timing_of_timing = function
      | Account.Timing.Untimed ->
          None
      | Timed t ->
          Some
            { Runtime_config.Accounts.Single.Timed.initial_minimum_balance =
                t.initial_minimum_balance
            ; cliff_time = t.cliff_time
            ; cliff_amount = t.cliff_amount
            ; vesting_period = t.vesting_period
            ; vesting_increment = t.vesting_increment
            }
    in
    let add_accounts accounts_and_keypairs =
      List.map accounts_and_keypairs
        ~f:(fun
             ( { Test_config.Test_account.balance
               ; account_name
               ; timing
               ; permissions
               ; zkapp
               }
             , (pk, sk) )
           ->
          let timing = runtime_timing_of_timing timing in
          let default = Runtime_config.Accounts.Single.default in
          let account =
            { default with
              pk = Public_key.Compressed.to_string pk
            ; sk = Some (Private_key.to_base58_check sk)
            ; balance = Balance.of_mina_string_exn balance
            ; delegate = None
            ; timing
            ; permissions =
                Option.map
                  ~f:Runtime_config.Accounts.Single.Permissions.of_permissions
                  permissions
            ; zkapp =
                Option.map
                  ~f:Runtime_config.Accounts.Single.Zkapp_account.of_zkapp zkapp
            }
          in
          (account_name, account) )
    in
    let genesis_accounts_and_keys = List.zip_exn genesis_ledger keypairs in
    let genesis_ledger_accounts = add_accounts genesis_accounts_and_keys in
    let constraint_constants =
      Genesis_ledger_helper.make_constraint_constants
        ~default:Genesis_constants.Constraint_constants.compiled proof_config
    in
    let ledger_is_prefix ledger1 ledger2 =
      List.is_prefix ledger2 ~prefix:ledger1
        ~equal:(fun
                 ({ account_name = name1; _ } : Test_config.Test_account.t)
                 ({ account_name = name2; _ } : Test_config.Test_account.t)
               -> String.equal name1 name2 )
    in
    let runtime_config =
      { Runtime_config.daemon =
          Some
            { txpool_max_size = Some txpool_max_size
            ; peer_list_url = None
            ; zkapp_proof_update_cost = None
            ; zkapp_signed_single_update_cost = None
            ; zkapp_signed_pair_update_cost = None
            ; zkapp_transaction_cost_limit = None
            ; max_event_elements = None
            ; max_action_elements = None
            ; zkapp_cmd_limit_hardcap = None
            ; slot_tx_end
            ; slot_chain_end
            }
      ; genesis =
          Some
            { k = Some k
            ; delta = Some delta
            ; slots_per_epoch = Some slots_per_epoch
            ; slots_per_sub_window = Some slots_per_sub_window
            ; grace_period_slots = Some grace_period_slots
            ; genesis_state_timestamp =
                Some Core.Time.(to_string_abs ~zone:Zone.utc (now ()))
            }
      ; proof = Some proof_config (* TODO: prebake ledger and only set hash *)
      ; ledger =
          Some
            { base =
                Accounts
                  (List.map genesis_ledger_accounts ~f:(fun (_name, acct) ->
                       acct ) )
            ; add_genesis_winner = None
            ; num_accounts = None
            ; balances = []
            ; hash = None
            ; s3_data_hash = None
            ; name = None
            }
      ; epoch_data =
          Option.map epoch_data ~f:(fun { staking = staking_ledger; next } ->
              let genesis_winner_account : Runtime_config.Accounts.single =
                Runtime_config.Accounts.Single.of_account
                  Mina_state.Consensus_state_hooks.genesis_winner_account
                |> Result.ok_or_failwith
              in
              let ledger_of_epoch_accounts
                  (epoch_accounts : Test_config.Test_account.t list) =
                let epoch_ledger_accounts =
                  List.map epoch_accounts
                    ~f:(fun
                         { account_name; balance; timing; permissions; zkapp }
                       ->
                      let balance = Balance.of_mina_string_exn balance in
                      let timing = runtime_timing_of_timing timing in
                      let genesis_account =
                        match
                          List.Assoc.find genesis_ledger_accounts account_name
                            ~equal:String.equal
                        with
                        | Some acct ->
                            acct
                        | None ->
                            failwithf
                              "Epoch ledger account %s not in genesis ledger"
                              account_name ()
                      in
                      { genesis_account with
                        balance
                      ; timing
                      ; permissions =
                          Option.map
                            ~f:
                              Runtime_config.Accounts.Single.Permissions
                              .of_permissions permissions
                      ; zkapp =
                          Option.map
                            ~f:
                              Runtime_config.Accounts.Single.Zkapp_account
                              .of_zkapp zkapp
                      } )
                in
                ( { base =
                      Accounts (genesis_winner_account :: epoch_ledger_accounts)
                  ; add_genesis_winner = None (* no effect *)
                  ; num_accounts = None
                  ; balances = []
                  ; hash = None
                  ; s3_data_hash = None
                  ; name = None
                  }
                  : Runtime_config.Ledger.t )
              in
              let staking =
                let ({ epoch_ledger; epoch_seed }
                      : Test_config.Epoch_data.Data.t ) =
                  staking_ledger
                in
                if not (ledger_is_prefix epoch_ledger genesis_ledger) then
                  failwith "Staking epoch ledger not a prefix of genesis ledger" ;
                let ledger = ledger_of_epoch_accounts epoch_ledger in
                let seed = epoch_seed in
                ({ ledger; seed } : Runtime_config.Epoch_data.Data.t)
              in
              let next =
                Option.map next ~f:(fun { epoch_ledger; epoch_seed } ->
                    if
                      not
                        (ledger_is_prefix staking_ledger.epoch_ledger
                           epoch_ledger )
                    then
                      failwith
                        "Staking epoch ledger not a prefix of next epoch ledger" ;
                    if not (ledger_is_prefix epoch_ledger genesis_ledger) then
                      failwith
                        "Next epoch ledger not a prefix of genesis ledger" ;
                    let ledger = ledger_of_epoch_accounts epoch_ledger in
                    let seed = epoch_seed in
                    ({ ledger; seed } : Runtime_config.Epoch_data.Data.t) )
              in
              ({ staking; next } : Runtime_config.Epoch_data.t) )
      }
    in
    let genesis_constants =
      Or_error.ok_exn
        (Genesis_ledger_helper.make_genesis_constants ~logger
           ~default:Genesis_constants.compiled runtime_config )
    in
    let constants : Test_config.constants =
      { constraints = constraint_constants; genesis = genesis_constants }
    in
    let mk_net_keypair keypair_name (pk, sk) =
      let keypair =
        { Keypair.public_key = Public_key.decompress_exn pk; private_key = sk }
      in
      Network_keypair.create_network_keypair ~keypair_name ~keypair
    in
    let long_commit_id =
      if String.is_substring Mina_version.commit_id ~substring:"[DIRTY]" then
        String.sub Mina_version.commit_id ~pos:7
          ~len:(String.length Mina_version.commit_id - 7)
      else Mina_version.commit_id
    in
    let mina_archive_base_url =
      "https://raw.githubusercontent.com/MinaProtocol/mina/" ^ long_commit_id
      ^ "/src/app/archive/"
    in
    let mina_archive_schema_aux_files =
      [ sprintf "%screate_schema.sql" mina_archive_base_url
      ; sprintf "%szkapp_tables.sql" mina_archive_base_url
      ]
    in
    let genesis_keypairs =
      List.fold genesis_accounts_and_keys ~init:String.Map.empty
        ~f:(fun map ({ account_name; _ }, (pk, sk)) ->
          let keypair = mk_net_keypair account_name (pk, sk) in
          String.Map.add_exn map ~key:account_name ~data:keypair )
    in
    let open Docker_node_config in
    let open Docker_compose.Dockerfile in
    let port_manager = PortManager.create ~min_port:10000 ~max_port:11000 in
    let docker_volumes =
      [ Base_node_config.runtime_config_volume
      ; Base_node_config.entrypoint_volume
      ]
    in
    let generate_random_id () =
      let rand_char () =
        let ascii_a = int_of_char 'a' in
        let ascii_z = int_of_char 'z' in
        char_of_int (ascii_a + Random.int (ascii_z - ascii_a + 1))
      in
      String.init 4 ~f:(fun _ -> rand_char ())
    in
    let seed_config =
      let config : Seed_config.config =
        { archive_address = None
        ; base_config =
            Base_node_config.default ~peer:None
              ~runtime_config_path:
                (Some Base_node_config.container_runtime_config_path)
              ~start_filtered_logs
        }
      in
      Seed_config.create
        ~service_name:(sprintf "seed-%s" (generate_random_id ()))
        ~image:images.mina
        ~ports:(PortManager.allocate_ports_for_node port_manager)
        ~volumes:(docker_volumes @ [ Seed_config.seed_libp2p_keypair ])
        ~config
    in
    let seed_config_peer =
      Some
        (Seed_config.create_libp2p_peer ~peer_name:seed_config.service_name
           ~external_port:PortManager.mina_internal_external_port )
    in
    let archive_node_configs =
      List.init num_archive_nodes ~f:(fun index ->
          let config =
            { Postgres_config.host =
                sprintf "postgres-%d-%s" (index + 1) (generate_random_id ())
            ; username = "postgres"
            ; password = "password"
            ; database = "archive"
            ; port = PortManager.postgres_internal_port
            }
          in
          let postgres_port =
            Service.Port.create
              ~published:(PortManager.allocate_port port_manager)
              ~target:PortManager.postgres_internal_port
          in
          let postgres_config =
            Postgres_config.create ~service_name:config.host
              ~image:Postgres_config.postgres_image ~ports:[ postgres_port ]
              ~volumes:
                [ Postgres_config.postgres_create_schema_volume
                ; Postgres_config.postgres_zkapp_schema_volume
                ; Postgres_config.postgres_entrypoint_volume
                ]
              ~config
          in
          let archive_server_port =
            Service.Port.create
              ~published:(PortManager.allocate_port port_manager)
              ~target:PortManager.mina_internal_server_port
          in
          let config : Archive_node_config.config =
            { postgres_config
            ; server_port = archive_server_port.target
            ; base_config =
                Base_node_config.default ~peer:None
                  ~runtime_config_path:
                    (Some Base_node_config.container_runtime_config_path)
                  ~start_filtered_logs
            }
          in
          let archive_rest_port =
            Service.Port.create
              ~published:(PortManager.allocate_port port_manager)
              ~target:PortManager.mina_internal_rest_port
          in
          Archive_node_config.create
            ~service_name:
              (sprintf "archive-%d-%s" (index + 1) (generate_random_id ()))
            ~image:images.archive_node
            ~ports:[ archive_server_port; archive_rest_port ]
            ~volumes:
              [ Base_node_config.runtime_config_volume
              ; Archive_node_config.archive_entrypoint_volume
              ]
            ~config )
    in
    (* Each archive node has it's own seed node *)
    let seed_configs =
      List.mapi archive_node_configs ~f:(fun index archive_config ->
          let config : Seed_config.config =
            { archive_address =
                Some
                  (sprintf "%s:%d" archive_config.service_name
                     PortManager.mina_internal_server_port )
            ; base_config =
                Base_node_config.default ~peer:seed_config_peer
                  ~runtime_config_path:
                    (Some Base_node_config.container_runtime_config_path)
                  ~start_filtered_logs
            }
          in
          Seed_config.create
            ~service_name:
              (sprintf "seed-%d-%s" (index + 1) (generate_random_id ()))
            ~image:images.mina
            ~ports:(PortManager.allocate_ports_for_node port_manager)
            ~volumes:docker_volumes ~config )
      @ [ seed_config ]
    in
    let block_producer_configs =
      List.map block_producers ~f:(fun node ->
          let keypair =
            match
              List.find genesis_accounts_and_keys
                ~f:(fun ({ account_name; _ }, _keypair) ->
                  String.equal account_name node.account_name )
            with
            | Some (_acct, keypair) ->
                keypair |> mk_net_keypair node.account_name
            | None ->
                let failstring =
                  Format.sprintf
                    "Failing because the account key of all initial block \
                     producers must be in the genesis ledger.  name of Node: \
                     %s.  name of Account which does not exist: %s"
                    node.node_name node.account_name
                in
                failwith failstring
          in
          let priv_key_path =
            Base_node_config.container_keys_path ^/ node.account_name
          in
          let volumes =
            [ Service.Volume.create ("keys" ^/ node.account_name) priv_key_path
            ]
            @ docker_volumes
          in
          let block_producer_config : Block_producer_config.config =
            { keypair
            ; priv_key_path
            ; enable_peer_exchange = true
            ; enable_flooding = true
            ; base_config =
                Base_node_config.default ~peer:seed_config_peer
                  ~runtime_config_path:
                    (Some Base_node_config.container_runtime_config_path)
                  ~start_filtered_logs
            }
          in
          Block_producer_config.create ~service_name:node.node_name
            ~image:images.mina
            ~ports:(PortManager.allocate_ports_for_node port_manager)
            ~volumes ~config:block_producer_config )
    in
    let snark_coordinator_config =
      match snark_coordinator with
      | None ->
          None
      | Some snark_coordinator_node ->
          let network_kp =
            match
              String.Map.find genesis_keypairs
                snark_coordinator_node.account_name
            with
            | Some acct ->
                acct
            | None ->
                let failstring =
                  Format.sprintf
                    "Failing because the account key of all initial snark \
                     coordinators must be in the genesis ledger.  name of \
                     Node: %s.  name of Account which does not exist: %s"
                    snark_coordinator_node.node_name
                    snark_coordinator_node.account_name
                in
                failwith failstring
          in
          let public_key =
            Public_key.Compressed.to_base58_check
              (Public_key.compress network_kp.keypair.public_key)
          in
          let coordinator_ports =
            PortManager.allocate_ports_for_node port_manager
          in
          let daemon_port =
            coordinator_ports
            |> List.find_exn ~f:(fun p ->
                   p.target
                   = Docker_node_config.PortManager.mina_internal_client_port )
          in
          let snark_node_service_name = snark_coordinator_node.node_name in
          let worker_node_config : Snark_worker_config.config =
            { daemon_address = snark_node_service_name
            ; daemon_port = Int.to_string daemon_port.target
            ; proof_level = "full"
            ; base_config =
                Base_node_config.default ~peer:None ~runtime_config_path:None
                  ~start_filtered_logs:[]
            }
          in
          let worker_nodes =
            List.init snark_coordinator_node.worker_nodes ~f:(fun index ->
                Docker_node_config.Snark_worker_config.create
                  ~service_name:
                    (sprintf "snark-worker-%d-%s" (index + 1)
                       (generate_random_id ()) )
                  ~image:images.mina
                  ~ports:
                    (Docker_node_config.PortManager.allocate_ports_for_node
                       port_manager )
                  ~volumes:docker_volumes ~config:worker_node_config )
          in
          let snark_coordinator_config : Snark_coordinator_config.config =
            { worker_nodes
            ; snark_worker_fee
            ; snark_coordinator_key = public_key
            ; work_selection = "seq"
            ; base_config =
                Base_node_config.default ~peer:seed_config_peer
                  ~runtime_config_path:
                    (Some Base_node_config.container_runtime_config_path)
                  ~start_filtered_logs
            }
          in
          Some
            (Snark_coordinator_config.create
               ~service_name:snark_node_service_name ~image:images.mina
               ~ports:coordinator_ports ~volumes:docker_volumes
               ~config:snark_coordinator_config )
    in
    { debug_arg = debug
    ; genesis_keypairs
    ; constants
    ; docker =
        { docker_swarm_version
        ; stack_name
        ; mina_image = images.mina
        ; mina_agent_image = images.user_agent
        ; mina_bots_image = images.bots
        ; mina_points_image = images.points
        ; mina_archive_image = images.archive_node
        ; runtime_config = Runtime_config.to_yojson runtime_config
        ; log_precomputed_blocks
        ; start_filtered_logs
        ; block_producer_configs
        ; seed_configs
        ; mina_archive_schema_aux_files
        ; snark_coordinator_config
        ; archive_node_configs
        }
    }

  (*
     Composes a docker_compose.json file from the network_config specification and writes to disk. This docker_compose
     file contains docker service definitions for each node in the local network. Each node service has different
     configurations which are specified as commands, environment variables, and docker bind volumes.
     We start by creating a runtime config volume to mount to each node service as a bind volume and then continue to create each
     node service. As we create each definition for a service, we specify the docker command, volume, and environment varibles to 
     be used (which are mostly defaults).
  *)
  let to_docker network_config =
    let open Docker_compose.Dockerfile in
    let block_producer_map =
      List.map network_config.docker.block_producer_configs ~f:(fun config ->
          (config.service_name, config.docker_config) )
      |> StringMap.of_alist_exn
    in
    let seed_map =
      List.map network_config.docker.seed_configs ~f:(fun config ->
          (config.service_name, config.docker_config) )
      |> StringMap.of_alist_exn
    in
    let snark_coordinator_map =
      match network_config.docker.snark_coordinator_config with
      | Some config ->
          StringMap.of_alist_exn [ (config.service_name, config.docker_config) ]
      | None ->
          StringMap.empty
    in
    let snark_worker_map =
      match network_config.docker.snark_coordinator_config with
      | Some snark_coordinator_config ->
          List.map snark_coordinator_config.config.worker_nodes
            ~f:(fun config -> (config.service_name, config.docker_config))
          |> StringMap.of_alist_exn
      | None ->
          StringMap.empty
    in
    let archive_node_map =
      List.map network_config.docker.archive_node_configs ~f:(fun config ->
          (config.service_name, config.docker_config) )
      |> StringMap.of_alist_exn
    in
    let postgres_map =
      List.map network_config.docker.archive_node_configs
        ~f:(fun archive_config ->
          let config = archive_config.config.postgres_config in
          (config.service_name, config.docker_config) )
      |> StringMap.of_alist_exn
    in
    let services =
      postgres_map |> merge archive_node_map |> merge snark_worker_map
      |> merge snark_coordinator_map
      |> merge block_producer_map |> merge seed_map
    in
    { version = docker_swarm_version; services }
end

module Network_manager = struct
  type t =
    { logger : Logger.t
    ; stack_name : string
    ; graphql_enabled : bool
    ; docker_dir : string
    ; docker_compose_file_path : string
    ; constants : Test_config.constants
    ; seed_workloads : Docker_network.Service_to_deploy.t Core.String.Map.t
    ; block_producer_workloads :
        Docker_network.Service_to_deploy.t Core.String.Map.t
    ; snark_coordinator_workloads :
        Docker_network.Service_to_deploy.t Core.String.Map.t
    ; snark_worker_workloads :
        Docker_network.Service_to_deploy.t Core.String.Map.t
    ; archive_workloads : Docker_network.Service_to_deploy.t Core.String.Map.t
    ; services_by_id : Docker_network.Service_to_deploy.t Core.String.Map.t
    ; mutable deployed : bool
    ; genesis_keypairs : Network_keypair.t Core.String.Map.t
    }

  let get_current_running_stacks =
    let open Malleable_error.Let_syntax in
    let%bind all_stacks_str =
      Util.run_cmd_or_hard_error "/" "docker"
        [ "stack"; "ls"; "--format"; "{{.Name}}" ]
    in
    return (String.split ~on:'\n' all_stacks_str)

  let remove_stack_if_exists ~logger (network_config : Network_config.t) =
    let open Malleable_error.Let_syntax in
    let%bind all_stacks = get_current_running_stacks in
    if List.mem all_stacks network_config.docker.stack_name ~equal:String.equal
    then
      let%bind () =
        if network_config.debug_arg then
          Deferred.bind ~f:Malleable_error.return
            (Util.prompt_continue
               "Existing stack name of same name detected, pausing startup. \
                Enter [y/Y] to continue on and remove existing stack name, \
                start clean, and run the test; press Ctrl-C to quit out: " )
        else
          Malleable_error.return
            ([%log info]
               "Existing stack of same name detected; removing to start clean" )
      in
      Util.run_cmd_or_hard_error "/" "docker"
        [ "stack"; "rm"; network_config.docker.stack_name ]
      >>| Fn.const ()
    else return ()

  let generate_docker_stack_file ~logger ~docker_dir ~docker_compose_file_path
      ~network_config =
    let open Deferred.Let_syntax in
    let%bind () =
      if%bind File_system.dir_exists docker_dir then (
        [%log info] "Old docker stack directory found; removing to start clean" ;
        File_system.remove_dir docker_dir )
      else return ()
    in
    [%log info] "Writing docker configuration %s" docker_dir ;
    let%bind () = Unix.mkdir docker_dir in
    let%bind _ =
      Docker_compose.Dockerfile.write_config ~dir:docker_dir
        ~filename:docker_compose_file_path
        (Network_config.to_docker network_config)
    in
    return ()

  let write_docker_bind_volumes ~logger ~docker_dir
      ~(network_config : Network_config.t) =
    let open Deferred.Let_syntax in
    [%log info] "Writing runtime_config %s" docker_dir ;
    let%bind () =
      Yojson.Safe.to_file
        (String.concat [ docker_dir; "/runtime_config.json" ])
        network_config.docker.runtime_config
      |> Deferred.return
    in
    [%log info] "Writing out the genesis keys to dir %s" docker_dir ;
    let kps_base_path = String.concat [ docker_dir; "/keys" ] in
    let%bind () = Unix.mkdir kps_base_path in
    [%log info] "Writing genesis keys to %s" kps_base_path ;
    let%bind () =
      Core.String.Map.iter network_config.genesis_keypairs ~f:(fun kp ->
          let keypath = String.concat [ kps_base_path; "/"; kp.keypair_name ] in
          Out_channel.with_file ~fail_if_exists:true keypath ~f:(fun ch ->
              kp.private_key |> Out_channel.output_string ch ) ;
          Out_channel.with_file ~fail_if_exists:true (keypath ^ ".pub")
            ~f:(fun ch -> kp.public_key |> Out_channel.output_string ch) ;
          ignore
            (Util.run_cmd_exn kps_base_path "chmod" [ "600"; kp.keypair_name ]) )
      |> Deferred.return
    in
    [%log info] "Writing seed libp2p keypair to %s" kps_base_path ;
    let%bind () =
      let keypath = String.concat [ kps_base_path; "/"; "libp2p_key" ] in
      Out_channel.with_file ~fail_if_exists:true keypath ~f:(fun ch ->
          Docker_node_config.Seed_config.libp2p_keypair
          |> Out_channel.output_string ch ) ;
      ignore (Util.run_cmd_exn kps_base_path "chmod" [ "600"; "libp2p_key" ]) ;
      return ()
    in
    let%bind () =
      ignore (Util.run_cmd_exn docker_dir "chmod" [ "700"; "keys" ])
      |> Deferred.return
    in
    [%log info]
      "Writing custom entrypoint script (libp2p key generation and puppeteer \
       context)" ;
    let entrypoint_filename, entrypoint_script =
      Docker_node_config.Base_node_config.entrypoint_script
    in
    Out_channel.with_file ~fail_if_exists:true
      (docker_dir ^/ entrypoint_filename) ~f:(fun ch ->
        entrypoint_script |> Out_channel.output_string ch ) ;
    [%log info]
      "Writing custom archive entrypoint script (wait for postgres to \
       initialize)" ;
    let archive_filename, archive_script =
      Docker_node_config.Archive_node_config.archive_entrypoint_script
    in
    Out_channel.with_file ~fail_if_exists:true (docker_dir ^/ archive_filename)
      ~f:(fun ch -> archive_script |> Out_channel.output_string ch) ;
    ignore (Util.run_cmd_exn docker_dir "chmod" [ "+x"; archive_filename ]) ;
    let%bind _ =
      Deferred.List.iter network_config.docker.mina_archive_schema_aux_files
        ~f:(fun schema_url ->
          let filename = Filename.basename schema_url in
          [%log info] "Downloading %s" schema_url ;
          let%bind _ =
            Util.run_cmd_or_hard_error docker_dir "curl"
              [ "-o"; filename; schema_url ]
          in
          [%log info]
            "Writing custom postgres entrypoint script (import archive node \
             schema)" ;

          Deferred.return () )
      |> Deferred.return
    in
    ignore (Util.run_cmd_exn docker_dir "chmod" [ "+x"; entrypoint_filename ]) ;
    [%log info] "Writing custom postgres entrypoint script (create schema)" ;
    let postgres_entrypoint_filename, postgres_entrypoint_script =
      Docker_node_config.Postgres_config.postgres_script
    in
    Out_channel.with_file ~fail_if_exists:true
      (docker_dir ^/ postgres_entrypoint_filename) ~f:(fun ch ->
        postgres_entrypoint_script |> Out_channel.output_string ch ) ;
    ignore
      (Util.run_cmd_exn docker_dir "chmod"
         [ "+x"; postgres_entrypoint_filename ] ) ;
    return ()

  let initialize_workloads ~logger (network_config : Network_config.t) =
    let find_rest_port ports =
      List.find_map_exn ports ~f:(fun port ->
          match port with
          | Docker_compose.Dockerfile.Service.Port.{ published; target } ->
              if target = Docker_node_config.PortManager.mina_internal_rest_port
              then Some published
              else None )
    in
    [%log info] "Initializing seed workloads" ;
    let seed_workloads =
      List.map network_config.docker.seed_configs ~f:(fun seed_config ->
          let graphql_port = find_rest_port seed_config.docker_config.ports in
          let node =
            Docker_network.Service_to_deploy.construct_service
              network_config.docker.stack_name seed_config.service_name
              (Docker_network.Service_to_deploy.init_service_to_deploy_config
                 ~network_keypair:None ~postgres_connection_uri:None
                 ~graphql_port )
          in
          (seed_config.service_name, node) )
      |> Core.String.Map.of_alist_exn
    in
    [%log info] "Initializing block producer workloads" ;
    let block_producer_workloads =
      List.map network_config.docker.block_producer_configs ~f:(fun bp_config ->
          let graphql_port = find_rest_port bp_config.docker_config.ports in
          let node =
            Docker_network.Service_to_deploy.construct_service
              network_config.docker.stack_name bp_config.service_name
              (Docker_network.Service_to_deploy.init_service_to_deploy_config
                 ~network_keypair:(Some bp_config.config.keypair)
                 ~postgres_connection_uri:None ~graphql_port )
          in
          (bp_config.service_name, node) )
      |> Core.String.Map.of_alist_exn
    in
    [%log info] "Initializing snark coordinator and worker workloads" ;
    let snark_coordinator_workloads, snark_worker_workloads =
      match network_config.docker.snark_coordinator_config with
      | Some snark_coordinator_config ->
          let snark_coordinator_workloads =
            if List.length snark_coordinator_config.config.worker_nodes > 0 then
              let graphql_port =
                find_rest_port snark_coordinator_config.docker_config.ports
              in
              let coordinator =
                Docker_network.Service_to_deploy.construct_service
                  network_config.docker.stack_name
                  snark_coordinator_config.service_name
                  (Docker_network.Service_to_deploy
                   .init_service_to_deploy_config ~network_keypair:None
                     ~postgres_connection_uri:None ~graphql_port )
              in
              [ (snark_coordinator_config.service_name, coordinator) ]
              |> Core.String.Map.of_alist_exn
            else Core.String.Map.empty
          in
          let snark_worker_workloads =
            List.map snark_coordinator_config.config.worker_nodes
              ~f:(fun snark_worker_config ->
                let graphql_port =
                  find_rest_port snark_worker_config.docker_config.ports
                in
                let worker =
                  Docker_network.Service_to_deploy.construct_service
                    network_config.docker.stack_name
                    snark_worker_config.service_name
                    (Docker_network.Service_to_deploy
                     .init_service_to_deploy_config ~network_keypair:None
                       ~postgres_connection_uri:None ~graphql_port )
                in

                (snark_worker_config.service_name, worker) )
            |> Core.String.Map.of_alist_exn
          in
          (snark_coordinator_workloads, snark_worker_workloads)
      | None ->
          (Core.String.Map.of_alist_exn [], Core.String.Map.of_alist_exn [])
    in
    [%log info] "Initializing archive node workloads" ;
    let archive_workloads =
      List.map network_config.docker.archive_node_configs
        ~f:(fun archive_config ->
          let graphql_port =
            find_rest_port archive_config.docker_config.ports
          in
          let postgres_connection_uri =
            Some
              (Docker_node_config.Postgres_config.to_connection_uri
                 archive_config.config.postgres_config.config )
          in
          let node =
            Docker_network.Service_to_deploy.construct_service
              network_config.docker.stack_name archive_config.service_name
              (Docker_network.Service_to_deploy.init_service_to_deploy_config
                 ~network_keypair:None ~postgres_connection_uri ~graphql_port )
          in
          (archive_config.service_name, node) )
      |> Core.String.Map.of_alist_exn
    in
    ( seed_workloads
    , block_producer_workloads
    , snark_coordinator_workloads
    , snark_worker_workloads
    , archive_workloads )

  let poll_until_stack_deployed ~logger =
    let poll_interval = Time.Span.of_sec 15.0 in
    let max_polls = 60 (* 15 mins *) in
    let get_service_statuses () =
      let%bind output =
        Util.run_cmd_exn "/" "docker"
          [ "service"; "ls"; "--format"; "{{.Name}}: {{.Replicas}}" ]
      in
      return
        ( output |> String.split_lines
        |> List.map ~f:(fun line ->
               match String.split ~on:':' line with
               | [ name; replicas ] ->
                   (String.strip name, String.strip replicas)
               | _ ->
                   failwith "Unexpected format for docker service output" ) )
    in
    let rec poll n =
      [%log debug] "Checking Docker service statuses, n=%d" n ;
      let%bind service_statuses = get_service_statuses () in
      let bad_service_statuses =
        List.filter service_statuses ~f:(fun (_, status) ->
            let parts = String.split ~on:'/' status in
            assert (List.length parts = 2) ;
            let num, denom =
              ( String.strip (List.nth_exn parts 0)
              , String.strip (List.nth_exn parts 1) )
            in
            not (String.equal num denom) )
      in
      let open Malleable_error.Let_syntax in
      if List.is_empty bad_service_statuses then return ()
      else if n > 0 then (
        [%log debug] "Got bad service statuses, polling again ($failed_statuses"
          ~metadata:
            [ ( "failed_statuses"
              , `Assoc
                  (List.Assoc.map bad_service_statuses ~f:(fun v -> `String v))
              )
            ] ;
        let%bind () =
          after poll_interval |> Deferred.bind ~f:Malleable_error.return
        in
        poll (n - 1) )
      else
        let bad_service_statuses_json =
          `List
            (List.map bad_service_statuses ~f:(fun (service_name, status) ->
                 `Assoc
                   [ ("service_name", `String service_name)
                   ; ("status", `String status)
                   ] ) )
        in
        [%log fatal]
          "Not all services could be deployed in time: $bad_service_statuses"
          ~metadata:[ ("bad_service_statuses", bad_service_statuses_json) ] ;
        Malleable_error.hard_error_string ~exit_code:4
          (Yojson.Safe.to_string bad_service_statuses_json)
    in
    [%log info] "Waiting for Docker services to be deployed" ;
    let res = poll max_polls in
    match%bind.Deferred res with
    | Error _ ->
        [%log error] "Not all Docker services were deployed, cannot proceed!" ;
        res
    | Ok _ ->
        [%log info] "Docker services deployed" ;
        res

  let create ~logger (network_config : Network_config.t) =
    let open Malleable_error.Let_syntax in
    let%bind () = remove_stack_if_exists ~logger network_config in
    let ( seed_workloads
        , block_producer_workloads
        , snark_coordinator_workloads
        , snark_worker_workloads
        , archive_workloads ) =
      initialize_workloads ~logger network_config
    in
    let services_by_id =
      let all_workloads =
        Core.String.Map.data seed_workloads
        @ Core.String.Map.data snark_coordinator_workloads
        @ Core.String.Map.data snark_worker_workloads
        @ Core.String.Map.data block_producer_workloads
        @ Core.String.Map.data archive_workloads
      in
      all_workloads
      |> List.map ~f:(fun w -> (w.service_name, w))
      |> String.Map.of_alist_exn
    in
    let open Deferred.Let_syntax in
    let docker_dir = network_config.docker.stack_name in
    let docker_compose_file_path =
      network_config.docker.stack_name ^ ".compose.json"
    in
    let%bind () =
      generate_docker_stack_file ~logger ~docker_dir ~docker_compose_file_path
        ~network_config
    in
    let%bind () =
      write_docker_bind_volumes ~logger ~docker_dir ~network_config
    in
    let t =
      { stack_name = network_config.docker.stack_name
      ; logger
      ; docker_dir
      ; docker_compose_file_path
      ; constants = network_config.constants
      ; graphql_enabled = true
      ; seed_workloads
      ; block_producer_workloads
      ; snark_coordinator_workloads
      ; snark_worker_workloads
      ; archive_workloads
      ; services_by_id
      ; deployed = false
      ; genesis_keypairs = network_config.genesis_keypairs
      }
    in
    [%log info] "Initializing docker swarm" ;
    Malleable_error.return t

  let deploy t =
    let logger = t.logger in
    if t.deployed then failwith "network already deployed" ;
    [%log info] "Deploying stack '%s' from %s" t.stack_name t.docker_dir ;
    let open Malleable_error.Let_syntax in
    let%bind (_ : string) =
      Util.run_cmd_or_hard_error t.docker_dir "docker"
        [ "stack"; "deploy"; "-c"; t.docker_compose_file_path; t.stack_name ]
    in
    t.deployed <- true ;
    let%bind () = poll_until_stack_deployed ~logger in
    let open Malleable_error.Let_syntax in
    let func_for_fold ~(key : string) ~data accum_M =
      let%bind mp = accum_M in
      let%map node =
        Docker_network.Service_to_deploy.get_node_from_service data
      in
      Core.String.Map.add_exn mp ~key ~data:node
    in
    let%map seeds =
      Core.String.Map.fold t.seed_workloads
        ~init:(Malleable_error.return Core.String.Map.empty)
        ~f:func_for_fold
    and block_producers =
      Core.String.Map.fold t.block_producer_workloads
        ~init:(Malleable_error.return Core.String.Map.empty)
        ~f:func_for_fold
    and snark_coordinators =
      Core.String.Map.fold t.snark_coordinator_workloads
        ~init:(Malleable_error.return Core.String.Map.empty)
        ~f:func_for_fold
    and snark_workers =
      Core.String.Map.fold t.snark_worker_workloads
        ~init:(Malleable_error.return Core.String.Map.empty)
        ~f:func_for_fold
    and archive_nodes =
      Core.String.Map.fold t.archive_workloads
        ~init:(Malleable_error.return Core.String.Map.empty)
        ~f:func_for_fold
    in
    let network =
      { Docker_network.namespace = t.stack_name
      ; constants = t.constants
      ; seeds
      ; block_producers
      ; snark_coordinators
      ; snark_workers
      ; archive_nodes
      ; genesis_keypairs = t.genesis_keypairs
      }
    in
    let nodes_to_string =
      Fn.compose (String.concat ~sep:", ") (List.map ~f:Docker_network.Node.id)
    in
    [%log info] "Network deployed" ;
    [%log info] "testnet namespace: %s" t.stack_name ;
    [%log info] "snark coordinators: %s"
      (nodes_to_string (Core.String.Map.data network.snark_coordinators)) ;
    [%log info] "snark workers: %s"
      (nodes_to_string (Core.String.Map.data network.snark_workers)) ;
    [%log info] "block producers: %s"
      (nodes_to_string (Core.String.Map.data network.block_producers)) ;
    [%log info] "archive nodes: %s"
      (nodes_to_string (Core.String.Map.data network.archive_nodes)) ;
    network

  let destroy t =
    [%log' info t.logger] "Destroying network" ;
    if not t.deployed then failwith "network not deployed" ;
    let%bind _ =
      Util.run_cmd_exn "/" "docker" [ "stack"; "rm"; t.stack_name ]
    in
    t.deployed <- false ;
    Deferred.unit

  let cleanup t =
    let%bind () = if t.deployed then destroy t else return () in
    [%log' info t.logger] "Cleaning up network configuration" ;
    let%bind () = File_system.remove_dir t.docker_dir in
    Deferred.unit

  let destroy t =
    Deferred.Or_error.try_with ~here:[%here] (fun () -> destroy t)
    |> Deferred.bind ~f:Malleable_error.or_hard_error
end

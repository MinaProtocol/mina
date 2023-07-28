open Core
open Async
open Currency
open Signature_lib
open Mina_base
open Integration_test_lib

let aws_region = "us-west-2"

let aws_route53_zone_id = "ZJPR9NA6W9M7F"

let project_id = "o1labs-192920"

let cluster_id = "gke_o1labs-192920_us-west1_mina-integration-west1"

let cluster_name = "mina-integration-west1"

let cluster_region = "us-west1"

let cluster_zone = "us-west1a"

module Network_config = struct
  module Cli_inputs = Cli_inputs

  (* This function computes the priority value of pods to use for the deployment. Pod priority will
   * determine the order of the queue in which unscheduled pods are scheduled onto nodes. By
   * computing the pod priority from the timestamp of the deployment, we ensure that earlier
   * deployments will take scheduling priority over older deployments that are also waiting to be
   * scheduled. For more information on pod priority, refer to the kubernetes documentation.
   * https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/#priorityclass
   *)
  let compute_pod_priority () =
    let pod_priority_genesis_timestamp = 1690569524 in
    let max_pod_priority = 1000000000 in
    let min_pod_priority = -2147483648 in
    let current_timestamp =
      Time.now () |> Time.to_span_since_epoch |> Time.Span.to_sec
      |> Float.to_int
    in
    let priority =
      max_pod_priority - (current_timestamp - pod_priority_genesis_timestamp)
    in
    assert (priority > min_pod_priority) ;
    priority

  type block_producer_config =
    { name : string (* ; id : string *)
    ; keypair : Network_keypair.t
    ; libp2p_secret : string
    }
  [@@deriving to_yojson]

  type snark_coordinator_config =
    { name : string; public_key : string; worker_nodes : int }
  [@@deriving to_yojson]

  type terraform_config =
    { k8s_context : string
    ; cluster_name : string
    ; cluster_region : string
    ; aws_route53_zone_id : string
    ; testnet_name : string
    ; deploy_graphql_ingress : bool
    ; mina_image : string
    ; mina_agent_image : string
    ; mina_bots_image : string
    ; mina_points_image : string
    ; mina_archive_image : string
          (* this field needs to be sent as a string to terraform, even though it's a json encoded value *)
    ; runtime_config : Yojson.Safe.t
          [@to_yojson fun j -> `String (Yojson.Safe.to_string j)]
    ; block_producer_configs : block_producer_config list
    ; log_precomputed_blocks : bool
    ; archive_node_count : int
    ; mina_archive_schema : string
    ; mina_archive_schema_aux_files : string list
    ; snark_coordinator_config : snark_coordinator_config option
    ; snark_worker_fee : string
    ; cpu_request : int
    ; mem_request : string
    ; worker_cpu_request : int
    ; worker_mem_request : string
    ; pod_priority : int
    }
  [@@deriving to_yojson]

  type t =
    { mina_automation_location : string
    ; debug_arg : bool
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
    ; terraform : terraform_config
    }
  [@@deriving to_yojson]

  let terraform_config_to_assoc t =
    let[@warning "-8"] (`Assoc assoc : Yojson.Safe.t) =
      terraform_config_to_yojson t
    in
    assoc

  let expand ~logger ~test_name ~(cli_inputs : Cli_inputs.t) ~(debug : bool)
      ~(test_config : Test_config.t) ~(images : Test_config.Container_images.t)
      =
    let { requires_graphql
        ; genesis_ledger
        ; block_producers
        ; snark_coordinator
        ; snark_worker_fee
        ; num_archive_nodes
        ; log_precomputed_blocks (* ; num_plain_nodes *)
        ; proof_config
        ; Test_config.k
        ; delta
        ; slots_per_epoch
        ; slots_per_sub_window
        ; txpool_max_size
        } =
      test_config
    in
    let user_from_env = Option.value (Unix.getenv "USER") ~default:"auto" in
    let user_sanitized =
      Str.global_replace (Str.regexp "\\W|_-") "" user_from_env
    in
    let user_len = Int.min 5 (String.length user_sanitized) in
    let user = String.sub user_sanitized ~pos:0 ~len:user_len in
    let git_commit = Mina_version.commit_id_short in
    (* see ./src/app/test_executive/README.md for information regarding the namespace name format and length restrictions *)
    let testnet_name = "it-" ^ user ^ "-" ^ git_commit ^ "-" ^ test_name in

    (* check to make sure the test writer hasn't accidentally created duplicate names of accounts and keys *)
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

    (* GENERATE ACCOUNTS AND KEYPAIRS *)
    let keypairs =
      List.take
        (* the first keypair is the genesis winner and is assumed to be untimed. Therefore dropping it, and not assigning it to any block producer *)
        (List.drop
           (Array.to_list (Lazy.force Key_gen.Sample_keypairs.keypairs))
           1 )
        (List.length genesis_ledger)
    in
    let labeled_accounts :
        ( Runtime_config.Accounts.single
        * (Public_key.Compressed.t * Private_key.t) )
        String.Map.t =
      String.Map.empty
    in
    let rec add_accounts mp zip =
      match zip with
      | [] ->
          mp
      | hd :: tl ->
          let ( { Test_config.Test_Account.balance; account_name; timing }
              , (pk, sk) ) =
            hd
          in
          let timing =
            match timing with
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
          let default = Runtime_config.Accounts.Single.default in
          let acct =
            { default with
              pk = Public_key.Compressed.to_string pk
            ; sk = Some (Private_key.to_base58_check sk)
            ; balance =
                Balance.of_mina_string_exn balance
                (* delegation currently unsupported *)
            ; delegate = None
            ; timing
            }
          in
          add_accounts
            (String.Map.add_exn mp ~key:account_name ~data:(acct, (pk, sk)))
            tl
    in
    let genesis_ledger_accounts =
      add_accounts labeled_accounts (List.zip_exn genesis_ledger keypairs)
    in
    (* DAEMON CONFIG *)
    let constraint_constants =
      Genesis_ledger_helper.make_constraint_constants
        ~default:Genesis_constants.Constraint_constants.compiled proof_config
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
            }
      ; genesis =
          Some
            { k = Some k
            ; delta = Some delta
            ; slots_per_epoch = Some slots_per_epoch
            ; slots_per_sub_window = Some slots_per_sub_window
            ; genesis_state_timestamp =
                Some Core.Time.(to_string_abs ~zone:Zone.utc (now ()))
            }
      ; proof = Some proof_config (* TODO: prebake ledger and only set hash *)
      ; ledger =
          Some
            { base =
                Accounts
                  (let tuplist = String.Map.data genesis_ledger_accounts in
                   List.map tuplist ~f:(fun tup ->
                       let acct, _ = tup in
                       acct ) )
            ; add_genesis_winner = None
            ; num_accounts = None
            ; balances = []
            ; hash = None
            ; name = None
            }
      ; epoch_data = None
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
    (* BLOCK PRODUCER CONFIG *)
    let mk_net_keypair keypair_name (pk, sk) =
      let keypair =
        { Keypair.public_key = Public_key.decompress_exn pk; private_key = sk }
      in
      Network_keypair.create_network_keypair ~keypair_name ~keypair
    in
    let block_producer_config name keypair =
      { name; keypair; libp2p_secret = "" }
    in
    let block_producer_configs =
      List.map block_producers ~f:(fun node ->
          let _, key_tup =
            match String.Map.find genesis_ledger_accounts node.account_name with
            | Some acct ->
                acct
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
          block_producer_config node.node_name
            (mk_net_keypair node.account_name key_tup) )
    in
    let mina_archive_schema = "create_schema.sql" in
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
      [ mina_archive_base_url ^ "create_schema.sql"
      ; mina_archive_base_url ^ "zkapp_tables.sql"
      ]
    in
    let genesis_keypairs =
      String.Map.of_alist_exn
        (List.map (String.Map.to_alist genesis_ledger_accounts)
           ~f:(fun element ->
             let kp_name, (_, (pk, sk)) = element in
             (kp_name, mk_net_keypair kp_name (pk, sk)) ) )
    in
    let snark_coordinator_config =
      match snark_coordinator with
      | None ->
          None
      | Some node ->
          let network_kp =
            match String.Map.find genesis_keypairs node.account_name with
            | Some acct ->
                acct
            | None ->
                let failstring =
                  Format.sprintf
                    "Failing because the account key of all initial snark \
                     coordinators must be in the genesis ledger.  name of \
                     Node: %s.  name of Account which does not exist: %s"
                    node.node_name node.account_name
                in
                failwith failstring
          in
          Some
            { name = node.node_name
            ; public_key =
                Public_key.Compressed.to_base58_check
                  (Public_key.compress network_kp.keypair.public_key)
            ; worker_nodes = node.worker_nodes
            }
    in

    (* NETWORK CONFIG *)
    { mina_automation_location = cli_inputs.mina_automation_location
    ; debug_arg = debug
    ; genesis_keypairs
    ; constants
    ; terraform =
        { cluster_name
        ; cluster_region
        ; k8s_context = cluster_id
        ; testnet_name
        ; deploy_graphql_ingress = requires_graphql
        ; mina_image = images.mina
        ; mina_agent_image = images.user_agent
        ; mina_bots_image = images.bots
        ; mina_points_image = images.points
        ; mina_archive_image = images.archive_node
        ; runtime_config = Runtime_config.to_yojson runtime_config
        ; block_producer_configs
        ; log_precomputed_blocks
        ; archive_node_count = num_archive_nodes
        ; mina_archive_schema
        ; mina_archive_schema_aux_files
        ; snark_coordinator_config
        ; snark_worker_fee
        ; aws_route53_zone_id
        ; cpu_request = 6
        ; mem_request = "12Gi"
        ; worker_cpu_request = 6
        ; worker_mem_request = "8Gi"
        ; pod_priority = compute_pod_priority ()
        }
    }

  let to_terraform network_config =
    let open Terraform in
    [ Block.Terraform
        { Block.Terraform.required_version = ">= 0.12.0"
        ; backend =
            Backend.Local
              { path =
                  "terraform-" ^ network_config.terraform.testnet_name
                  ^ ".tfstate"
              }
        }
    ; Block.Provider
        { Block.Provider.provider = "google"
        ; region = cluster_region
        ; zone = Some cluster_zone
        ; project = Some project_id
        ; alias = None
        }
    ; Block.Module
        { Block.Module.local_name = "integration_testnet"
        ; providers = [ ("google.gke", "google") ]
        ; source = "../../modules/o1-integration"
        ; args = terraform_config_to_assoc network_config.terraform
        }
    ]

  let testnet_log_filter network_config =
    Printf.sprintf
      {|
        resource.labels.project_id="%s"
        resource.labels.location="%s"
        resource.labels.cluster_name="%s"
        resource.labels.namespace_name="%s"
      |}
      project_id cluster_region cluster_name
      network_config.terraform.testnet_name
end

module Network_manager = struct
  type t =
    { logger : Logger.t
    ; testnet_name : string
    ; cluster : string
    ; namespace : string
    ; graphql_enabled : bool
    ; testnet_dir : string
    ; testnet_log_filter : string
    ; constants : Test_config.constants
    ; seed_workloads : Kubernetes_network.Workload_to_deploy.t Core.String.Map.t
    ; block_producer_workloads :
        Kubernetes_network.Workload_to_deploy.t Core.String.Map.t
    ; snark_coordinator_workloads :
        Kubernetes_network.Workload_to_deploy.t Core.String.Map.t
    ; snark_worker_workloads :
        Kubernetes_network.Workload_to_deploy.t Core.String.Map.t
    ; archive_workloads :
        Kubernetes_network.Workload_to_deploy.t Core.String.Map.t
    ; workloads_by_id :
        Kubernetes_network.Workload_to_deploy.t Core.String.Map.t
    ; mutable deployed : bool
    ; genesis_keypairs : Network_keypair.t Core.String.Map.t
    }

  let run_cmd t prog args = Util.run_cmd t.testnet_dir prog args

  let run_cmd_exn t prog args = Util.run_cmd_exn t.testnet_dir prog args

  let run_cmd_or_hard_error t prog args =
    Util.run_cmd_or_hard_error t.testnet_dir prog args

  let create ~logger (network_config : Network_config.t) =
    let open Malleable_error.Let_syntax in
    let%bind current_cluster =
      Util.run_cmd_or_hard_error "/" "kubectl" [ "config"; "current-context" ]
    in
    [%log info] "Using cluster: %s" current_cluster ;
    let%bind all_namespaces_str =
      Util.run_cmd_or_hard_error "/" "kubectl"
        [ "get"; "namespaces"; "-ojsonpath={.items[*].metadata.name}" ]
    in
    let all_namespaces = String.split ~on:' ' all_namespaces_str in
    let%bind () =
      if
        List.mem all_namespaces network_config.terraform.testnet_name
          ~equal:String.equal
      then
        let%bind () =
          if network_config.debug_arg then
            Deferred.bind ~f:Malleable_error.return
              (Util.prompt_continue
                 "Existing namespace of same name detected, pausing startup. \
                  Enter [y/Y] to continue on and remove existing namespace, \
                  start clean, and run the test; press Cntrl-C to quit out: " )
          else
            Malleable_error.return
              ([%log info]
                 "Existing namespace of same name detected; removing to start \
                  clean" )
        in
        Util.run_cmd_or_hard_error "/" "kubectl"
          [ "delete"; "namespace"; network_config.terraform.testnet_name ]
        >>| Fn.const ()
      else return ()
    in
    (* TODO: prebuild genesis proof and ledger *)
    let testnet_log_filter = Network_config.testnet_log_filter network_config in
    (* we currently only deploy 1 seed and coordinator per deploy (will be configurable later) *)
    (* seed node keyname and workload name hardcoded as "seed" *)
    let seed_workloads =
      Core.String.Map.add_exn Core.String.Map.empty ~key:"seed"
        ~data:
          (Kubernetes_network.Workload_to_deploy.construct_workload "seed"
             (Kubernetes_network.Workload_to_deploy.cons_pod_info "mina") )
    in

    let snark_coordinator_workloads, snark_worker_workloads =
      match network_config.terraform.snark_coordinator_config with
      | Some config ->
          let snark_coordinator_workloads =
            if config.worker_nodes > 0 then
              Core.String.Map.of_alist_exn
                [ ( config.name
                  , Kubernetes_network.Workload_to_deploy.construct_workload
                      config.name
                      (Kubernetes_network.Workload_to_deploy.cons_pod_info
                         "mina" ) )
                ]
            else Core.String.Map.of_alist_exn []
          in
          let snark_worker_workloads =
            if config.worker_nodes > 0 then
              Core.String.Map.of_alist_exn
                [ ( config.name ^ "-worker"
                  , Kubernetes_network.Workload_to_deploy.construct_workload
                      (config.name ^ "-worker")
                      (Kubernetes_network.Workload_to_deploy.cons_pod_info
                         "worker" ) )
                ]
            else Core.String.Map.of_alist_exn []
          in
          (snark_coordinator_workloads, snark_worker_workloads)
      | None ->
          (Core.String.Map.of_alist_exn [], Core.String.Map.of_alist_exn [])
    in
    (*
         let snark_coordinator_id =
           String.lowercase
             (String.sub network_config.terraform.snark_worker_public_key
                ~pos:
                  (String.length network_config.terraform.snark_worker_public_key - 6)
                ~len:6 )
         in
         let snark_coordinator_workloads =
           if network_config.terraform.snark_worker_replicas > 0 then
             [ Kubernetes_network.Workload_to_deploy.construct_workload
                 ("snark-coordinator-" ^ snark_coordinator_id)
                 [ Kubernetes_network.Workload_to_deploy.cons_pod_info "mina" ]
             ]
           else []
         in
         let snark_worker_workloads =
           if network_config.terraform.snark_worker_replicas > 0 then
             [ Kubernetes_network.Workload_to_deploy.construct_workload
                 ("snark-worker-" ^ snark_coordinator_id)
                 (List.init network_config.terraform.snark_worker_replicas
                    ~f:(fun _i ->
                      Kubernetes_network.Workload_to_deploy.cons_pod_info "worker" )
                 )
             ]
           else []
         in *)
    let block_producer_workloads =
      List.map network_config.terraform.block_producer_configs
        ~f:(fun bp_config ->
          ( bp_config.name
          , Kubernetes_network.Workload_to_deploy.construct_workload
              bp_config.name
              (Kubernetes_network.Workload_to_deploy.cons_pod_info
                 ~network_keypair:bp_config.keypair "mina" ) ) )
      |> Core.String.Map.of_alist_exn
    in
    let archive_workloads =
      List.init network_config.terraform.archive_node_count ~f:(fun i ->
          ( sprintf "archive-%d" (i + 1)
          , Kubernetes_network.Workload_to_deploy.construct_workload
              (sprintf "archive-%d" (i + 1))
              (Kubernetes_network.Workload_to_deploy.cons_pod_info
                 ~has_archive_container:true "mina" ) ) )
      |> Core.String.Map.of_alist_exn
    in
    let workloads_by_id =
      let all_workloads =
        Core.String.Map.data seed_workloads
        @ Core.String.Map.data snark_coordinator_workloads
        @ Core.String.Map.data snark_worker_workloads
        @ Core.String.Map.data block_producer_workloads
        @ Core.String.Map.data archive_workloads
      in
      all_workloads
      |> List.map ~f:(fun w -> (w.workload_id, w))
      |> String.Map.of_alist_exn
    in
    let testnet_dir =
      network_config.mina_automation_location ^/ "terraform/testnets"
      ^/ network_config.terraform.testnet_name
    in
    let t =
      { logger
      ; cluster = cluster_id
      ; namespace = network_config.terraform.testnet_name
      ; testnet_name = network_config.terraform.testnet_name
      ; graphql_enabled = network_config.terraform.deploy_graphql_ingress
      ; testnet_dir
      ; testnet_log_filter
      ; constants = network_config.constants
      ; seed_workloads
      ; block_producer_workloads
      ; snark_coordinator_workloads
      ; snark_worker_workloads
      ; archive_workloads
      ; workloads_by_id
      ; deployed = false
      ; genesis_keypairs = network_config.genesis_keypairs
      }
    in
    (* making the main.tf.json *)
    let open Deferred.Let_syntax in
    let%bind () =
      if%bind File_system.dir_exists testnet_dir then (
        [%log info] "Old terraform directory found; removing to start clean" ;
        File_system.remove_dir testnet_dir )
      else return ()
    in
    [%log info] "Making testnet dir %s" testnet_dir ;
    let%bind () = Unix.mkdir testnet_dir in
    let tf_filename = testnet_dir ^/ "main.tf.json" in
    [%log info] "Writing network configuration into %s" tf_filename ;
    Out_channel.with_file ~fail_if_exists:true tf_filename ~f:(fun ch ->
        Network_config.to_terraform network_config
        |> Terraform.to_string
        |> Out_channel.output_string ch ) ;
    [%log info]
      "Writing out the genesis keys (in case you want to use them manually) to \
       testnet dir %s"
      testnet_dir ;
    let kps_base_path = String.concat [ testnet_dir; "/genesis_keys" ] in
    let%bind () = Unix.mkdir kps_base_path in
    let%bind () =
      Core.String.Map.iter network_config.genesis_keypairs ~f:(fun kp ->
          Network_keypair.to_yojson kp
          |> Yojson.Safe.to_file
               (String.concat [ kps_base_path; "/"; kp.keypair_name; ".json" ]) )
      |> Deferred.return
    in
    [%log info] "Initializing terraform" ;
    let open Malleable_error.Let_syntax in
    let%bind (_ : string) = run_cmd_or_hard_error t "terraform" [ "init" ] in
    let%map (_ : string) = run_cmd_or_hard_error t "terraform" [ "validate" ] in
    t

  let deploy t =
    let open Malleable_error.Let_syntax in
    let logger = t.logger in
    if t.deployed then failwith "network already deployed" ;
    [%log info] "Deploying network" ;
    let%bind (_ : string) =
      run_cmd_or_hard_error t "terraform" [ "apply"; "-auto-approve" ]
    in
    t.deployed <- true ;
    let config : Kubernetes_network.config =
      { testnet_name = t.testnet_name
      ; cluster = t.cluster
      ; namespace = t.namespace
      ; graphql_enabled = t.graphql_enabled
      }
    in
    let func_for_fold ~(key : string) ~data accum_M =
      let%bind mp = accum_M in
      let%map node =
        Kubernetes_network.Workload_to_deploy.get_nodes_from_workload data
          ~config
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
      { Kubernetes_network.namespace = t.namespace
      ; constants = t.constants
      ; seeds
      ; block_producers
      ; snark_coordinators
      ; snark_workers
      ; archive_nodes (* ; all_nodes *)
      ; testnet_log_filter = t.testnet_log_filter
      ; genesis_keypairs = t.genesis_keypairs
      }
    in
    let nodes_to_string =
      Fn.compose (String.concat ~sep:", ")
        (List.map ~f:Kubernetes_network.Node.id)
    in
    [%log info] "Network deployed" ;
    [%log info] "testnet namespace: %s" t.namespace ;
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
    let%bind _ = run_cmd_exn t "terraform" [ "destroy"; "-auto-approve" ] in
    t.deployed <- false ;
    Deferred.unit

  let cleanup t =
    let%bind () = if t.deployed then destroy t else return () in
    [%log' info t.logger] "Cleaning up network configuration" ;
    let%bind () = File_system.remove_dir t.testnet_dir in
    Deferred.unit

  let destroy t =
    Deferred.Or_error.try_with ~here:[%here] (fun () -> destroy t)
    |> Deferred.bind ~f:Malleable_error.or_hard_error
end

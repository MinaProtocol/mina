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

  type block_producer_config =
    { name : string
    ; id : string
    ; keypair : Network_keypair.t
    ; public_key : string
    ; private_key : string
    ; keypair_secret : string
    ; libp2p_secret : string
    }
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
    ; snark_worker_replicas : int
    ; snark_worker_fee : string
    ; snark_worker_public_key : string
    ; cpu_request : int
    ; mem_request : string
    ; worker_cpu_request : int
    ; worker_mem_request : string
    }
  [@@deriving to_yojson]

  type t =
    { mina_automation_location : string
    ; debug_arg : bool (* ; keypairs : Network_keypair.t list *)
    ; check_capacity : bool
    ; check_capacity_delay : int
    ; check_capacity_retries : int
    ; block_producer_keypairs : Network_keypair.t list
    ; extra_genesis_keypairs : Network_keypair.t list
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
    let { Test_config.k
        ; delta
        ; slots_per_epoch
        ; slots_per_sub_window
        ; txpool_max_size
        ; requires_graphql
        ; block_producers
        ; extra_genesis_accounts
        ; num_snark_workers
        ; num_archive_nodes
        ; log_precomputed_blocks
        ; snark_worker_fee
        ; snark_worker_public_key
        ; proof_config
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
    (* GENERATE ACCOUNTS AND KEYPAIRS *)
    let num_block_producers = List.length block_producers in
    let bp_keypairs, extra_keypairs =
      List.split_n
        (* the first keypair is the genesis winner and is assumed to be untimed. Therefore dropping it, and not assigning it to any block producer *)
        (List.drop
           (Array.to_list (Lazy.force Key_gen.Sample_keypairs.keypairs))
           1 )
        num_block_producers
    in
    if List.length bp_keypairs < num_block_producers then
      failwith
        "not enough sample keypairs for specified number of block producers" ;
    assert (List.length bp_keypairs >= num_block_producers) ;
    if List.length bp_keypairs < num_block_producers then
      failwith
        "not enough sample keypairs for specified number of extra keypairs" ;
    assert (List.length extra_keypairs >= List.length extra_genesis_accounts) ;
    let extra_keypairs_cut =
      List.take extra_keypairs (List.length extra_genesis_accounts)
    in
    let extra_accounts =
      List.map (List.zip_exn extra_genesis_accounts extra_keypairs_cut)
        ~f:(fun ({ Test_config.Wallet.balance; timing }, (pk, sk)) ->
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
          { default with
            pk = Some (Public_key.Compressed.to_string pk)
          ; sk = Some (Private_key.to_base58_check sk)
          ; balance =
              Balance.of_formatted_string balance
              (* delegation currently unsupported *)
          ; delegate = None
          ; timing
          } )
    in
    let bp_accounts =
      List.map (List.zip_exn block_producers bp_keypairs)
        ~f:(fun ({ Test_config.Wallet.balance; timing }, (pk, _)) ->
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
          (* an account may be used for snapp transactions, so add
             permissions
          *)
          let (permissions : Runtime_config.Accounts.Single.Permissions.t option)
              =
            Some
              { edit_state = None
              ; send = None
              ; receive = None
              ; set_delegate = None
              ; set_permissions = None
              ; set_verification_key = None
              ; set_zkapp_uri = None
              ; edit_sequence_state = None
              ; set_token_symbol = None
              ; increment_nonce = None
              ; set_voting_for = None
              }
          in
          let default = Runtime_config.Accounts.Single.default in
          { default with
            pk = Some (Public_key.Compressed.to_string pk)
          ; sk = None
          ; balance =
              Balance.of_formatted_string balance
              (* delegation currently unsupported *)
          ; delegate = None
          ; timing
          ; permissions
          } )
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
            ; transaction_expiry_hr = None
            ; max_proof_zkapp_command = None
            ; max_zkapp_command = None
            ; max_event_elements = None
            ; max_sequence_event_elements = None
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
            { base = Accounts (bp_accounts @ extra_accounts)
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
    let block_producer_config index keypair =
      { name = "test-block-producer-" ^ Int.to_string (index + 1)
      ; id = Int.to_string index
      ; keypair
      ; keypair_secret = keypair.secret_name
      ; public_key = keypair.public_key_file
      ; private_key = keypair.private_key_file
      ; libp2p_secret = ""
      }
    in
    let mina_archive_schema = "create_schema.sql" in
    let mina_archive_base_url =
      "https://raw.githubusercontent.com/MinaProtocol/mina/"
      ^ Mina_version.commit_id ^ "/src/app/archive/"
    in
    let mina_archive_schema_aux_files =
      [ mina_archive_base_url ^ "create_schema.sql"
      ; mina_archive_base_url ^ "zkapp_tables.sql"
      ]
    in
    let mk_net_keypair index (pk, sk) =
      let secret_name = "test-keypair-" ^ Int.to_string index in
      let keypair =
        { Keypair.public_key = Public_key.decompress_exn pk; private_key = sk }
      in
      Network_keypair.create_network_keypair ~keypair ~secret_name
    in
    let extra_genesis_net_keypairs =
      List.mapi extra_keypairs_cut ~f:mk_net_keypair
    in
    let bp_net_keypairs = List.mapi bp_keypairs ~f:mk_net_keypair in
    (* NETWORK CONFIG *)
    { mina_automation_location = cli_inputs.mina_automation_location
    ; debug_arg = debug
    ; check_capacity = cli_inputs.check_capacity
    ; check_capacity_delay = cli_inputs.check_capacity_delay
    ; check_capacity_retries = cli_inputs.check_capacity_retries
    ; block_producer_keypairs = bp_net_keypairs
    ; extra_genesis_keypairs = extra_genesis_net_keypairs
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
        ; block_producer_configs =
            List.mapi bp_net_keypairs ~f:block_producer_config
        ; log_precomputed_blocks
        ; archive_node_count = num_archive_nodes
        ; mina_archive_schema
        ; mina_archive_schema_aux_files
        ; snark_worker_replicas = num_snark_workers
        ; snark_worker_public_key
        ; snark_worker_fee
        ; aws_route53_zone_id
        ; cpu_request = 6
        ; mem_request = "12Gi"
        ; worker_cpu_request = 4
        ; worker_mem_request = "6Gi"
        }
    }

  let to_terraform network_config =
    let open Terraform in
    [ Block.Terraform
        { Block.Terraform.required_version = ">= 0.12.0"
        ; backend =
            Backend.S3
              { Backend.S3.key =
                  "terraform-" ^ network_config.terraform.testnet_name
                  ^ ".tfstate"
              ; encrypt = true
              ; region = aws_region
              ; bucket = "o1labs-terraform-state"
              ; acl = "bucket-owner-full-control"
              }
        }
    ; Block.Provider
        { Block.Provider.provider = "aws"
        ; region = aws_region
        ; zone = None
        ; project = None
        ; alias = None
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
    ; seed_workloads : Kubernetes_network.Workload.t list
    ; block_producer_workloads : Kubernetes_network.Workload.t list
    ; snark_coordinator_workloads : Kubernetes_network.Workload.t list
    ; snark_worker_workloads : Kubernetes_network.Workload.t list
    ; archive_workloads : Kubernetes_network.Workload.t list
    ; workloads_by_id : Kubernetes_network.Workload.t String.Map.t
    ; mutable deployed : bool (* ; keypairs : Keypair.t list *)
    ; block_producer_keypairs : Keypair.t list
    ; extra_genesis_keypairs : Keypair.t list
    }

  let run_cmd t prog args = Util.run_cmd t.testnet_dir prog args

  let run_cmd_exn t prog args = Util.run_cmd_exn t.testnet_dir prog args

  let run_cmd_or_hard_error t prog args =
    Util.run_cmd_or_hard_error t.testnet_dir prog args

  let rec check_kube_capacity t ~logger ~(retries : int) ~(delay : float) :
      unit Malleable_error.t =
    let open Malleable_error.Let_syntax in
    let%bind () =
      Malleable_error.return ([%log info] "Running capacity check")
    in
    let%bind kubectl_top_nodes_output =
      Util.run_cmd_or_hard_error "/" "kubectl"
        [ "top"; "nodes"; "--sort-by=cpu"; "--no-headers" ]
    in
    let num_kube_nodes =
      String.split_on_chars kubectl_top_nodes_output ~on:[ '\n' ] |> List.length
    in
    let%bind gcloud_descr_output =
      Util.run_cmd_or_hard_error "/" "gcloud"
        [ "container"
        ; "clusters"
        ; "describe"
        ; cluster_name
        ; "--project"
        ; "o1labs-192920"
        ; "--region"
        ; cluster_region
        ]
    in
    (* gcloud container clusters describe mina-integration-west1 --project o1labs-192920 --region us-west1
        this command gives us lots of information, including the max number of nodes per node pool.
    *)
    let%bind max_node_count_str =
      Util.run_cmd_or_hard_error "/" "bash"
        [ "-c"
        ; Format.sprintf "echo \"%s\" | grep \"maxNodeCount\" "
            gcloud_descr_output
        ]
    in
    let max_node_count_by_node_pool =
      Re2.find_all_exn (Re2.of_string "[0-9]+") max_node_count_str
      |> List.map ~f:(fun str -> Int.of_string str)
    in
    (* We can have any number of node_pools.  this string parsing will yield a list of ints, each int represents the
        max_node_count for each node pool *)
    let max_nodes =
      List.fold max_node_count_by_node_pool ~init:0 ~f:(fun accum max_nodes ->
          accum + (max_nodes * 3) )
      (*
        the max_node_count_by_node_pool is per zone.  us-west1 has 3 zones (we assume this never changes).
          therefore to get the actual number of nodes a node_pool has, we multiply by 3.
          then we sum up the number of nodes in all our node_pools to get the actual total maximum number of nodes that we can scale up to *)
    in
    let nodes_available = max_nodes - num_kube_nodes in
    let cpus_needed_estimate =
      6
      * ( List.length t.seed_workloads
        + List.length t.block_producer_keypairs
        + List.length t.snark_coordinator_workloads )
      (* as of 2022/07, the seed, bps, and the snark coordinator use 6 cpus.  this is just a rough heuristic so we're not bothering to calculate memory needed *)
    in
    let cluster_nodes_needed =
      Int.of_float
        (Float.round_up (Float.( / ) (Float.of_int cpus_needed_estimate) 64.0))
      (* assuming that each node on the cluster has 64 cpus, as we've configured it to be in GCP as of *)
    in
    if nodes_available >= cluster_nodes_needed then
      let%bind () =
        Malleable_error.return
          ([%log info]
             "Capacity check passed.  %d nodes are provisioned, the cluster \
              can scale up to a max of %d nodes.  This test needs at least 1 \
              node to be unprovisioned."
             num_kube_nodes max_nodes )
      in
      Malleable_error.return ()
    else if retries <= 0 then
      let%bind () =
        Malleable_error.return
          ([%log info]
             "Capacity check failed.  %d nodes are provisioned, the cluster \
              can scale up to a max of %d nodes.  This test needs at least 1 \
              node to be unprovisioned.  no more retries, thus exiting"
             num_kube_nodes max_nodes )
      in
      exit 7
    else
      let%bind () =
        Malleable_error.return
          ([%log info]
             "Capacity check failed.  %d nodes are provisioned, the cluster \
              can scale up to a max of %d nodes.  This test needs at least 1 \
              node to be unprovisioned.  sleeping for 60 seconds before \
              retrying.  will retry %d more times"
             num_kube_nodes max_nodes (retries - 1) )
      in
      let%bind () = Malleable_error.return (Thread.delay delay) in
      check_kube_capacity t ~logger ~retries:(retries - 1) ~delay

  let create ~logger (network_config : Network_config.t) =
    let open Malleable_error.Let_syntax in
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
    (*
    let%bind inputs =
      Genesis_ledger_helper.Genesis_proof.generate_inputs ~proof_level ~ledger
        ~constraint_constants ~genesis_constants
    in
    let%bind (_, genesis_proof_filename) =
      Genesis_ledger_helper.Genesis_proof.load_or_generate ~logger ~genesis_dir
        inputs
    in
    *)
    let testnet_log_filter = Network_config.testnet_log_filter network_config in
    let cons_workload workload_id node_info : Kubernetes_network.Workload.t =
      { workload_id; node_info }
    in
    let cons_node_info ?network_keypair ?(has_archive_container = false)
        primary_container_id : Kubernetes_network.Node.info =
      { network_keypair; has_archive_container; primary_container_id }
    in
    (* we currently only deploy 1 seed and coordinator per deploy (will be configurable later) *)
    let seed_workloads = [ cons_workload "seed" [ cons_node_info "mina" ] ] in
    let snark_coordinator_id =
      String.lowercase
        (String.sub network_config.terraform.snark_worker_public_key
           ~pos:
             (String.length network_config.terraform.snark_worker_public_key - 6)
           ~len:6 )
    in
    let snark_coordinator_workloads =
      if network_config.terraform.snark_worker_replicas > 0 then
        [ cons_workload
            ("snark-coordinator-" ^ snark_coordinator_id)
            [ cons_node_info "mina" ]
        ]
      else []
    in
    let snark_worker_workloads =
      if network_config.terraform.snark_worker_replicas > 0 then
        [ cons_workload
            ("snark-worker-" ^ snark_coordinator_id)
            (List.init network_config.terraform.snark_worker_replicas
               ~f:(fun _i -> cons_node_info "worker") )
        ]
      else []
    in
    let block_producer_workloads =
      List.map network_config.terraform.block_producer_configs
        ~f:(fun bp_config ->
          cons_workload bp_config.name
            [ cons_node_info ~network_keypair:bp_config.keypair "mina" ] )
    in
    let archive_workloads =
      List.init network_config.terraform.archive_node_count ~f:(fun i ->
          cons_workload
            (sprintf "archive-%d" (i + 1))
            [ cons_node_info ~has_archive_container:true "mina" ] )
    in
    let workloads_by_id =
      let all_workloads =
        seed_workloads @ snark_coordinator_workloads @ snark_worker_workloads
        @ block_producer_workloads @ archive_workloads
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
      ; block_producer_keypairs =
          List.map network_config.block_producer_keypairs
            ~f:(fun { keypair; _ } -> keypair)
      ; extra_genesis_keypairs =
          List.map network_config.extra_genesis_keypairs
            ~f:(fun { keypair; _ } -> keypair)
      }
    in
    (* check capacity *)
    let%bind () =
      if network_config.check_capacity then
        check_kube_capacity t ~logger
          ~delay:(Float.of_int network_config.check_capacity_delay)
          ~retries:network_config.check_capacity_retries
      else Malleable_error.return ()
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
    let%map seeds =
      Malleable_error.List.map t.seed_workloads
        ~f:(Kubernetes_network.Workload.get_nodes ~config)
      >>| List.concat
    and block_producers =
      Malleable_error.List.map t.block_producer_workloads
        ~f:(Kubernetes_network.Workload.get_nodes ~config)
      >>| List.concat
    and snark_coordinators =
      Malleable_error.List.map t.snark_coordinator_workloads
        ~f:(Kubernetes_network.Workload.get_nodes ~config)
      >>| List.concat
    and snark_workers =
      Malleable_error.List.map t.snark_worker_workloads
        ~f:(Kubernetes_network.Workload.get_nodes ~config)
      >>| List.concat
    and archive_nodes =
      Malleable_error.List.map t.archive_workloads
        ~f:(Kubernetes_network.Workload.get_nodes ~config)
      >>| List.concat
    in
    let all_nodes =
      seeds @ block_producers @ snark_coordinators @ snark_workers
      @ archive_nodes
    in
    let nodes_by_pod_id =
      all_nodes
      |> List.map ~f:(fun node -> (node.pod_id, node))
      |> String.Map.of_alist_exn
    in
    let result =
      { Kubernetes_network.namespace = t.namespace
      ; constants = t.constants
      ; seeds
      ; block_producers
      ; snark_coordinators
      ; snark_workers
      ; archive_nodes
      ; nodes_by_pod_id
      ; testnet_log_filter = t.testnet_log_filter
      ; block_producer_keypairs = t.block_producer_keypairs
      ; extra_genesis_keypairs = t.extra_genesis_keypairs
      }
    in
    let nodes_to_string =
      Fn.compose (String.concat ~sep:", ")
        (List.map ~f:Kubernetes_network.Node.id)
    in
    [%log info] "Network deployed" ;
    [%log info] "testnet namespace: %s" t.namespace ;
    [%log info] "snark coordinators: %s"
      (nodes_to_string result.snark_coordinators) ;
    [%log info] "snark workers: %s" (nodes_to_string result.snark_workers) ;
    [%log info] "block producers: %s" (nodes_to_string result.block_producers) ;
    [%log info] "archive nodes: %s" (nodes_to_string result.archive_nodes) ;
    result

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
    Deferred.Or_error.try_with (fun () -> destroy t)
    |> Deferred.bind ~f:Malleable_error.or_hard_error
end

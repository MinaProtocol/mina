open Core
open Async
open Integration_test_lib
open Ci_interaction

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
    ; seed_workloads : Abstract_network.Workload_to_deploy.t Core.String.Map.t
    ; block_producer_workloads :
        Abstract_network.Workload_to_deploy.t Core.String.Map.t
    ; snark_coordinator_workloads :
        Abstract_network.Workload_to_deploy.t Core.String.Map.t
    ; snark_worker_workloads :
        Abstract_network.Workload_to_deploy.t Core.String.Map.t
    ; archive_workloads :
        Abstract_network.Workload_to_deploy.t Core.String.Map.t
    ; workloads_by_id : Abstract_network.Workload_to_deploy.t Core.String.Map.t
    ; mutable deployed : bool
    ; genesis_keypairs : Network_keypair.t Core.String.Map.t
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
      * ( Core.Map.length t.seed_workloads
        + Core.Map.length t.block_producer_workloads
        + Core.Map.length t.snark_coordinator_workloads )
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
          (Abstract_network.Workload_to_deploy.construct_workload "seed"
             (Abstract_network.Workload_to_deploy.cons_pod_info "mina") )
    in

    let snark_coordinator_workloads, snark_worker_workloads =
      match network_config.terraform.snark_coordinator_config with
      | Some config ->
          let snark_coordinator_workloads =
            if config.worker_nodes > 0 then
              Core.String.Map.of_alist_exn
                [ ( config.name
                  , Abstract_network.Workload_to_deploy.construct_workload
                      config.name
                      (Abstract_network.Workload_to_deploy.cons_pod_info "mina")
                  )
                ]
            else Core.String.Map.of_alist_exn []
          in
          let snark_worker_workloads =
            if config.worker_nodes > 0 then
              Core.String.Map.of_alist_exn
                [ ( config.name ^ "-worker"
                  , Abstract_network.Workload_to_deploy.construct_workload
                      (config.name ^ "-worker")
                      (Abstract_network.Workload_to_deploy.cons_pod_info
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
             [ Abstract_network.Workload_to_deploy.construct_workload
                 ("snark-coordinator-" ^ snark_coordinator_id)
                 [ Abstract_network.Workload_to_deploy.cons_pod_info "mina" ]
             ]
           else []
         in
         let snark_worker_workloads =
           if network_config.terraform.snark_worker_replicas > 0 then
             [ Abstract_network.Workload_to_deploy.construct_workload
                 ("snark-worker-" ^ snark_coordinator_id)
                 (List.init network_config.terraform.snark_worker_replicas
                    ~f:(fun _i ->
                      Abstract_network.Workload_to_deploy.cons_pod_info "worker" )
                 )
             ]
           else []
         in *)
    let block_producer_workloads =
      List.map network_config.terraform.block_producer_configs
        ~f:(fun bp_config ->
          ( bp_config.name
          , Abstract_network.Workload_to_deploy.construct_workload
              bp_config.name
              (Abstract_network.Workload_to_deploy.cons_pod_info
                 ~network_keypair:bp_config.keypair "mina" ) ) )
      |> Core.String.Map.of_alist_exn
    in
    let archive_workloads =
      List.init network_config.terraform.archive_node_count ~f:(fun i ->
          ( sprintf "archive-%d" (i + 1)
          , Abstract_network.Workload_to_deploy.construct_workload
              (sprintf "archive-%d" (i + 1))
              (Abstract_network.Workload_to_deploy.cons_pod_info
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
    let config : Abstract_network.config =
      { testnet_name = t.testnet_name
      ; cluster = t.cluster
      ; namespace = t.namespace
      ; graphql_enabled = t.graphql_enabled
      ; access_token = "access_token" (* TODO: *)
      ; network_id = "network_id" (* TODO: *)
      ; ingress_uri = "ingress_uri" (* TODO: *)
      ; current_commit_sha = "0000000" (* TODO: *)
      }
    in
    let func_for_fold ~(key : string) ~data accum_M =
      let%bind mp = accum_M in
      let%map node =
        Abstract_network.Workload_to_deploy.get_nodes_from_workload data ~config
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
      { Abstract_network.network_id = t.namespace (* TODO: fix *)
      ; constants = t.constants
      ; seeds
      ; block_producers
      ; snark_coordinators
      ; snark_workers
      ; archive_nodes
      ; testnet_log_filter = t.testnet_log_filter
      ; genesis_keypairs = t.genesis_keypairs
      }
    in
    let nodes_to_string =
      Fn.compose (String.concat ~sep:", ")
        (List.map ~f:Abstract_network.Node.id)
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
    Deferred.Or_error.try_with (fun () -> destroy t)
    |> Deferred.bind ~f:Malleable_error.or_hard_error
end

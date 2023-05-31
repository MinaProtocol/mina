open Integration_test_lib
open Config
open Network_config
open Core_kernel
open Mina_bootstrapper
open Mina_daemon

module Network_manager = struct
  type t =
    { logger : Logger.t
    ; constants : Test_config.constants
    ; seed_workloads : Config.t Core.String.Map.t
    ; block_producer_workloads :  Config.t Core.String.Map.t
    ; snark_coordinator_workloads : Config.t Core.String.Map.t
    ; snark_worker_workloads : Config.t Core.String.Map.t
    ; archive_workloads : Config.t Core.String.Map.t
    ; workloads_by_id : Config.t Core.String.Map.t
    ; mutable deployed : bool
    ; genesis_keypairs : Network_keypair.t Core.String.Map.t
    }

  let create ~logger (network_config : Network_config.t) =
    let port = ref (9000 + Random.int 100) in
    let open Malleable_error.Let_syntax in
    let seed_workloads =
      Core.String.Map.add_exn Core.String.Map.empty ~key:"seed"
        ~data:(Config.default !port)
    in
    port := (!port) + 1;
    let snark_coordinator_workloads, snark_worker_workloads =
      match network_config.terraform.snark_coordinator_config with
      | Some config ->
          let snark_coordinator_workloads =
            if config.worker_nodes > 0 then
              Core.String.Map.of_alist_exn
                [ ( config.name
                  , Config.default !port)
                ]
            else Core.String.Map.of_alist_exn []
          in
          let snark_worker_workloads =
            if config.worker_nodes > 0 then
              (port := (!port) + 1;
              Core.String.Map.of_alist_exn
                [ ( config.name ^ "-worker",  Config.default !port )])
            else Core.String.Map.of_alist_exn []
          in
          (snark_coordinator_workloads, snark_worker_workloads)
      | None ->
          (Core.String.Map.of_alist_exn [], Core.String.Map.of_alist_exn [])
    in
    port := (!port) + 1;
    let block_producer_workloads =
      List.map network_config.terraform.block_producer_configs
        ~f:(fun bp_config ->
          ( bp_config.name
          , Config.default !port ) )
      |> Core.String.Map.of_alist_exn
    in
    port := (!port) + 1;
    let archive_workloads =
      List.init network_config.terraform.archive_node_count ~f:(fun i ->
          ( sprintf "archive-%d" (i + 1)
          , Config.default !port ) )
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
      |> List.map ~f:(fun w -> (w.mina_exe, w))
      |> String.Map.of_alist_exn
    in
    { logger
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

  let deploy t =
    let open Malleable_error.Let_syntax in
    let logger = t.logger in
    if t.deployed then failwith "network already deployed" ;
    [%log info] "Deploying network" ;
    t.deployed <- true ;
    let func_for_fold ~(key : string) ~data accum_M =
      let%bind mp = accum_M in
      let bootstrapper = MinaBootstrapper.create data in
      let%bind process = MinaBootstrapper.start bootstrapper in
      let daemon = MinaDaemon.create process config in
      let node = { 
        app_id : key
        ; daemon
      }
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

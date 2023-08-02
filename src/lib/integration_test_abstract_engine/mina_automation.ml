open Core
open Async
open Integration_test_lib
open Ci_interaction

module Network_manager = struct
  type t =
    { logger : Logger.t
    ; network_id : string
    ; graphql_enabled : bool
    ; testnet_dir : string
    ; testnet_log_filter : string
    ; constants : Test_config.constants
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
      (* TODO: replace with run_command *)
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
        List.mem all_namespaces network_config.config.network_id
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
            @@ [%log info]
                 "Existing namespace of same name detected; removing to start \
                  clean"
        in
        (* TODO: replace with run_command *)
        Util.run_cmd_or_hard_error "/" "kubectl"
          [ "delete"; "namespace"; network_config.config.network_id ]
        >>| Fn.const ()
      else return ()
    in
    (* TODO: prebuild genesis proof and ledger *)
    let testnet_log_filter = Network_config.testnet_log_filter network_config in
    (* we currently only deploy 1 seed and coordinator per deploy (will be configurable later) *)
    (* seed node keyname and workload name hardcoded as "seed" *)
    let testnet_dir =
      network_config.config.config_dir ^/ "/testnets"
      ^/ network_config.config.network_id
    in
    let t =
      { logger
      ; network_id = network_config.config.network_id
      ; graphql_enabled = true
      ; testnet_dir
      ; testnet_log_filter
      ; constants = network_config.constants
      ; deployed = false
      ; genesis_keypairs = network_config.genesis_keypairs
      }
    in
    let open Deferred.Let_syntax in
    [%log info] "Making testnet dir %s" testnet_dir ;
    let%bind () = Unix.mkdir testnet_dir in
    let network_config_filename = testnet_dir ^/ "network_config.json" in
    [%log info] "Writing network configuration into %s" network_config_filename ;
    Out_channel.with_file ~fail_if_exists:true network_config_filename
      ~f:(fun ch ->
        Network_config.to_yojson network_config
        |> Yojson.Safe.to_string
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
    Malleable_error.return t

  (* TODO: use output *)
  let deploy t =
    let logger = t.logger in
    if t.deployed then failwith "network already deployed" ;
    [%log info] "Deploying network" ;
    let%bind output =
      let open Network_deployed in
      match%map
        run_command
          ~config:!Abstract_network.config_path
          ~args:[] "deploy_network"
      with
      | Ok output ->
          output |> Yojson.Safe.from_string |> of_yojson
          |> Result.ok_or_failwith
      | Error err ->
          raise @@ Invalid_output err
    in
    let _ = Map.is_empty output in
    t.deployed <- true ;
    let seeds = Core.String.Map.empty in
    let block_producers = Core.String.Map.empty in
    let snark_coordinators = Core.String.Map.empty in
    let snark_workers = Core.String.Map.empty in
    let archive_nodes = Core.String.Map.empty in
    let network =
      { Abstract_network.constants = t.constants
      ; testnet_log_filter = t.testnet_log_filter
      ; genesis_keypairs = t.genesis_keypairs
      ; seeds
      ; block_producers
      ; snark_coordinators
      ; snark_workers
      ; archive_nodes
      ; network_id = t.network_id
      }
    in
    let nodes_to_string =
      Fn.compose (String.concat ~sep:", ")
        (List.map ~f:Abstract_network.Node.id)
    in
    [%log info] "Network deployed" ;
    [%log info] "network id: %s" t.network_id ;
    [%log info] "snark coordinators: %s"
      (nodes_to_string (Core.String.Map.data network.snark_coordinators)) ;
    [%log info] "snark workers: %s"
      (nodes_to_string (Core.String.Map.data network.snark_workers)) ;
    [%log info] "block producers: %s"
      (nodes_to_string (Core.String.Map.data network.block_producers)) ;
    [%log info] "archive nodes: %s"
      (nodes_to_string (Core.String.Map.data network.archive_nodes)) ;
    Malleable_error.return network

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

open Core
open Core_unix
open Async
open Integration_test_lib
open Config_util

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
    ; runtime_config_path : string
    ; topology_path : string
    }

  let run_cmd t prog args = Util.run_cmd t.testnet_dir prog args

  let run_cmd_exn t prog args = Util.run_cmd_exn t.testnet_dir prog args

  let run_cmd_or_hard_error t prog args =
    Util.run_cmd_or_hard_error t.testnet_dir prog args

  let create ~logger (network_config : Network_config.t) _test_config =
    let open Malleable_error.Let_syntax in
    let testnet_dir =
      network_config.config.config_dir ^/ "/testnets"
      ^/ network_config.config.network_id
    in
    let%bind () =
      if Stdlib.Sys.file_exists testnet_dir then
        Deferred.bind ~f:Malleable_error.return
          (Deferred.map
             (Util.prompt_continue
                "Existing namespace of same name detected, pausing startup. \
                 Enter [y/Y] to continue on and remove existing namespace, \
                 start clean, and run the test; press Ctrl-C to quit out: " )
             ~f:(fun () ->
               let rec rmrf path =
                 let open Stdlib in
                 match Sys.is_directory path with
                 | true ->
                     Sys.readdir path
                     |> Array.iter (fun name ->
                            rmrf (Filename.concat path name) ) ;
                     Core.Unix.rmdir path
                 | false ->
                     Sys.remove path
               in
               [%log info] "Deleting old testnet dir %s" testnet_dir ;
               rmrf testnet_dir ) )
      else Malleable_error.return ()
    in
    (* TODO: prebuild genesis proof and ledger and cache for future use *)
    let testnet_log_filter = Network_config.testnet_log_filter network_config in
    (* we currently only deploy 1 seed and coordinator per deploy (will be configurable later) *)
    (* seed node keyname and workload name hardcoded as "seed" *)
    [%log info] "Making new testnet dir %s" testnet_dir ;
    mkdir_p testnet_dir ;
    let network_config_filename = testnet_dir ^/ "network_config.json" in
    let runtime_config_filename = testnet_dir ^/ "runtime_config.json" in
    let topology_filename = testnet_dir ^/ "topology.json" in
    let t =
      { logger
      ; network_id = network_config.config.network_id
      ; graphql_enabled = true
      ; testnet_dir
      ; testnet_log_filter
      ; constants = network_config.constants
      ; deployed = false
      ; genesis_keypairs = network_config.genesis_keypairs
      ; runtime_config_path = runtime_config_filename
      ; topology_path = topology_filename
      }
    in
    [%log info] "Writing network configuration to %s" network_config_filename ;
    Out_channel.with_file ~fail_if_exists:true network_config_filename
      ~f:(fun ch ->
        Network_config.to_yojson network_config |> Yojson.Safe.to_channel ch ) ;
    [%log info] "Writing runtime configuration to %s" runtime_config_filename ;
    Out_channel.with_file ~fail_if_exists:true runtime_config_filename
      ~f:(fun ch ->
        network_config.config.runtime_config |> Yojson.Safe.to_channel ch ) ;
    [%log info] "Writing topology to %s" topology_filename ;
    Out_channel.with_file ~fail_if_exists:true topology_filename ~f:(fun ch ->
        network_config.config.topology |> Yojson.Safe.to_channel ch ) ;
    [%log info] "Writing out the genesis keys to testnet dir %s" testnet_dir ;
    let kps_base_path = testnet_dir ^ "/genesis_keys" in
    let open Deferred.Let_syntax in
    let%bind () = Unix.mkdir kps_base_path in
    let%bind () =
      Core.String.Map.iter network_config.genesis_keypairs ~f:(fun kp ->
          Network_keypair.to_yojson kp
          |> Yojson.Safe.to_file
               (sprintf "%s/%s.json" kps_base_path kp.keypair_name) )
      |> Deferred.return
    in
    Malleable_error.return t

  let deploy t =
    let open Network_deployed in
    let logger = t.logger in
    if t.deployed then failwith "network already deployed" ;
    [%log info] "Deploying network" ;
    let%bind network_deployed =
      match%map
        Config_file.run_command
          ~config:!Abstract_network.config_path
          ~args:
            [ ("network_id", `String t.network_id)
            ; ("runtime_config", `String t.runtime_config_path)
            ; ("topology", `String t.topology_path)
            ]
          "create_network"
      with
      | Ok output ->
          output |> Yojson.Safe.from_string |> of_yojson
          |> Result.ok_or_failwith
      | Error err ->
          raise @@ Invalid_output err
    in
    t.deployed <- true ;
    let network =
      let open Abstract_network in
      { constants = t.constants
      ; testnet_log_filter = t.testnet_log_filter
      ; genesis_keypairs = t.genesis_keypairs
      ; archive_nodes = Node.Collections.archive_nodes network_deployed
      ; block_producers = Node.Collections.block_producers network_deployed
      ; seeds = Node.Collections.seeds network_deployed
      ; snark_coordinators =
          Node.Collections.snark_coordinators network_deployed
      ; snark_workers = Node.Collections.snark_workers network_deployed
      ; network_id = t.network_id
      }
    in
    let nodes_to_string nodes =
      Core.String.Map.data nodes
      |> Fn.compose (String.concat ~sep:", ")
           (List.map ~f:Abstract_network.Node.id)
    in
    [%log info] "Network deployed" ;
    [%log info] "network id: %s" t.network_id ;
    [%log info] "snark coordinators: %s"
      (nodes_to_string network.snark_coordinators) ;
    [%log info] "snark workers: %s" (nodes_to_string network.snark_workers) ;
    [%log info] "block producers: %s" (nodes_to_string network.block_producers) ;
    [%log info] "archive nodes: %s" (nodes_to_string network.archive_nodes) ;
    Malleable_error.return network

  let destroy t =
    [%log' info t.logger] "Destroying network" ;
    if not t.deployed then failwith "network not deployed" ;
    let%bind _ =
      Config_file.run_command ~config:!config_path
        ~args:[ ("network_id", `String t.network_id) ]
        "delete_network"
    in
    t.deployed <- false ;
    Deferred.unit

  let cleanup t =
    let%bind () = if t.deployed then destroy t else return () in
    [%log' info t.logger] "Cleaning up network directory" ;
    let%bind () = File_system.remove_dir t.testnet_dir in
    Deferred.unit

  let destroy t =
    Deferred.Or_error.try_with (fun () -> destroy t)
    |> Deferred.bind ~f:Malleable_error.or_hard_error
end

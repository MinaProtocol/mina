open Core_kernel
open Async
open Integration_test_lib
open Mina_daemon

let mina_archive_container_id = "archive"

let mina_archive_username = "mina"

let mina_archive_pw = "zo3moong7moog4Iep7eNgo3iecaesahH"

let postgres_url =
  Printf.sprintf "postgres://%s:%s@localhost:5432/archive"
    mina_archive_username mina_archive_pw

let node_password = "naughty blue worm"

module Node = struct
  type t =
    { app_id : string
    ; daemon : MinaDaemon.t
    ; network_keypair : Network_keypair.t option
    }

  let id { app_id; _ } = app_id

  let network_keypair { network_keypair; _ } = network_keypair

  let start ~_fresh_state _node : unit Malleable_error.t =
    Malleable_error.ok_unit

  let stop node =
    MinaDaemon.force_kill node.daemon

 let graphql_client ~logger t= MinaDaemon.get_graphql_api t.daemon ~logger
 
  let dump_archive_data ~_logger (_t : t) ~_data_file =
    Malleable_error.ok_unit

  let run_replayer ~_logger (_t : t) = 
    Malleable_error.return ()

  let dump_mina_logs ~_logger (_t : t) ~_log_file =
    Malleable_error.return ()

  let dump_precomputed_blocks ~_logger (_t : t) =
    Malleable_error.return ()
    
end

type t =
  { 
  constants : Test_config.constants
  ; seeds : Node.t Core.String.Map.t
  ; block_producers : Node.t Core.String.Map.t
  ; snark_coordinators : Node.t Core.String.Map.t
  ; snark_workers : Node.t Core.String.Map.t
  ; archive_nodes : Node.t Core.String.Map.t
        (* ; nodes_by_pod_id : Node.t Core.String.Map.t *)
  ; testnet_log_filter : string
  ; genesis_keypairs : Network_keypair.t Core.String.Map.t
  }

let constants { constants; _ } = constants

let constraint_constants { constants; _ } = constants.constraints

let genesis_constants { constants; _ } = constants.genesis

let seeds { seeds; _ } = seeds

let block_producers { block_producers; _ } = block_producers

let snark_coordinators { snark_coordinators; _ } = snark_coordinators

let snark_workers { snark_workers; _ } = snark_workers

let archive_nodes { archive_nodes; _ } = archive_nodes

(* all_nodes returns all *actual* mina nodes; note that a snark_worker is a pod within the network but not technically a mina node, therefore not included here.  snark coordinators on the other hand ARE mina nodes *)
let all_nodes { seeds; block_producers; snark_coordinators; archive_nodes; _ } =
  List.concat
    [ Core.String.Map.to_alist seeds
    ; Core.String.Map.to_alist block_producers
    ; Core.String.Map.to_alist snark_coordinators
    ; Core.String.Map.to_alist archive_nodes
    ]
  |> Core.String.Map.of_alist_exn

(* all_pods returns everything in the network.  remember that snark_workers will never initialize and will never sync, and aren't supposed to *)
(* TODO snark workers and snark coordinators have the same key name, but different workload ids*)
let all_pods t =
  List.concat
    [ Core.String.Map.to_alist t.seeds
    ; Core.String.Map.to_alist t.block_producers
    ; Core.String.Map.to_alist t.snark_coordinators
    ; Core.String.Map.to_alist t.snark_workers
    ; Core.String.Map.to_alist t.archive_nodes
    ]
  |> Core.String.Map.of_alist_exn

(* all_non_seed_pods returns everything in the network except seed nodes *)
let all_non_seed_pods t =
  List.concat
    [ Core.String.Map.to_alist t.block_producers
    ; Core.String.Map.to_alist t.snark_coordinators
    ; Core.String.Map.to_alist t.snark_workers
    ; Core.String.Map.to_alist t.archive_nodes
    ]
  |> Core.String.Map.of_alist_exn

let genesis_keypairs { genesis_keypairs; _ } = genesis_keypairs

let initialize_infra ~_logger _network =
  ()

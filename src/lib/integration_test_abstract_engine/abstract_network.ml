open Core_kernel
open Async
open Integration_test_lib
open Config_util

(* exclude from bisect_ppx to avoid type error on GraphQL modules *)
[@@@coverage exclude_file]

let config_path = config_path

let keypairs_path = keypairs_path

let mina_image = mina_image

let alias = alias

let archive_image = archive_image

module Node = struct
  type t =
    { node_id : Node_id.t
    ; network_id : Network_id.t
    ; network_keypair : Network_keypair.t option
    ; node_type : Node_type.t
    ; password : string
    ; graphql_uri : string
    }

  let id { node_id; _ } = node_id

  let network_keypair { network_keypair; _ } = network_keypair

  let get_ingress_uri node = Uri.of_string node.graphql_uri

  let start ~fresh_state t : unit Malleable_error.t =
    try
      let args =
        [ ("fresh_state", `Bool fresh_state)
        ; ("network_id", `String t.network_id)
        ; ("node_id", `String t.node_id)
        ]
      in
      let%bind () =
        match%map
          Config_file.run_command ~config:!config_path ~args "start_node"
        with
        | Ok output ->
            Yojson.Safe.from_string output
            |> Node_started.of_yojson |> Result.ok_or_failwith |> ignore
        | _ ->
            failwith "invalid node started response"
      in
      Malleable_error.return ()
    with Failure err -> Malleable_error.hard_error_string err

  let stop t =
    try
      let args =
        [ ("network_id", `String t.network_id); ("node_id", `String t.node_id) ]
      in
      let%bind () =
        match%map
          Config_file.run_command ~config:!config_path ~args "stop_node"
        with
        | Ok output ->
            Yojson.Safe.from_string output
            |> Node_stopped.of_yojson |> Result.ok_or_failwith |> ignore
        | _ ->
            failwith "invalid node stopped response"
      in
      Malleable_error.return ()
    with Failure err -> Malleable_error.hard_error_string err

  let logger_metadata node =
    [ ("network_id", `String node.network_id)
    ; ("node_id", `String node.node_id)
    ]

  module Collections = struct
    let f network_id (node_info : Network_deployed.node_info) =
      { node_id = node_info.node_id
      ; network_id
      ; network_keypair = node_info.network_keypair
      ; node_type = node_info.node_type
      ; password = "naughty blue worm"
      ; graphql_uri = Option.value node_info.graphql_uri ~default:""
      }

    open Network_deployed
    open Core.String.Map

    let network_id t = data t |> List.hd_exn |> network_id

    let archive_nodes t =
      filter ~f:is_archive_node t |> map ~f:(f @@ network_id t)

    let block_producers t =
      filter ~f:is_block_producer t |> map ~f:(f @@ network_id t)

    let seeds t = filter ~f:is_seed_node t |> map ~f:(f @@ network_id t)

    let snark_coordinators t =
      filter t ~f:is_snark_coordinator |> map ~f:(f @@ network_id t)

    let snark_workers t =
      filter ~f:is_snark_worker t |> map ~f:(f @@ network_id t)
  end

  let dump_archive_data ~logger (t : t) ~data_file =
    let args =
      [ ("network_id", `String t.network_id); ("node_id", `String t.node_id) ]
    in
    if Node_type.(equal t.node_type Archive_node) then
      try
        let%bind dump =
          match%map
            Config_file.run_command ~config:!config_path ~args
              "dump_archive_data"
          with
          | Ok output ->
              Yojson.Safe.from_string output
              |> Archive_data_dump.of_yojson |> Result.ok_or_failwith
          | Error err ->
              raise @@ Archive_data_dump.Invalid_response err
        in
        [%log info] "Dumping archive data to file %s" data_file ;
        Malleable_error.return
        @@ Out_channel.with_file data_file ~f:(fun out_ch ->
               Out_channel.output_string out_ch dump.data )
      with Failure err -> Malleable_error.hard_error_string err
    else
      let node_type = Node_type.to_string t.node_type in
      [%log error] "Node $node_id cannot dump archive data as a $node_type"
        ~metadata:(("node_type", `String node_type) :: args) ;
      Malleable_error.hard_error_string
      @@ sprintf "Node %s of type %s cannot dump archive data" t.node_id
           node_type

  let run_replayer ?(start_slot_since_genesis = 0) ~logger (t : t) =
    let open Malleable_error.Let_syntax in
    [%log info] "Running replayer on archived data node: %s" t.node_id ;
    let args =
      [ ("network_id", `String t.network_id)
      ; ("node_id", `String t.node_id)
      ; ("start_slot_since_genesis", `Int start_slot_since_genesis)
      ]
    in
    try
      let%bind replay =
        match%map
          Deferred.bind ~f:Malleable_error.return
          @@ Config_file.run_command ~config:!config_path ~args "run_replayer"
        with
        | Ok output ->
            Yojson.Safe.from_string output
            |> Replayer_run.of_yojson |> Result.ok_or_failwith
        | Error err ->
            raise @@ Replayer_run.Invalid_response err
      in
      Malleable_error.return replay.logs
    with Failure err -> Malleable_error.hard_error_string err

  let dump_mina_logs ~logger (t : t) ~log_file =
    [%log info] "Dumping logs from node: %s" t.node_id ;
    let args =
      [ ("network_id", `String t.network_id); ("node_id", `String t.node_id) ]
    in
    try
      let%bind dump =
        match%map
          Config_file.run_command ~config:!config_path ~args "dump_mina_logs"
        with
        | Ok output ->
            Yojson.Safe.from_string output
            |> Mina_logs_dump.of_yojson |> Result.ok_or_failwith
        | Error err ->
            raise @@ Mina_logs_dump.Invalid_response err
      in
      [%log info] "Dumping logs to file %s" log_file ;
      Malleable_error.return
      @@ Out_channel.with_file log_file ~f:(fun out_ch ->
             Out_channel.output_string out_ch dump.logs )
    with Failure err -> Malleable_error.hard_error_string err

  let dump_precomputed_blocks ~logger (t : t) =
    [%log info] "Dumping precomputed blocks from logs for node: %s" t.node_id ;
    let args =
      [ ("network_id", `String t.network_id); ("node_id", `String t.node_id) ]
    in
    try
      let%bind dump =
        match%map
          Config_file.run_command ~config:!config_path ~args
            "dump_precomputed_blocks"
        with
        | Ok output ->
            Yojson.Safe.from_string output
            |> Precomputed_block_dump.of_yojson |> Result.ok_or_failwith
        | Error err ->
            raise @@ Precomputed_block_dump.Invalid_response err
      in
      let log_lines =
        String.split dump.blocks ~on:'\n'
        |> List.filter ~f:(String.is_prefix ~prefix:"{\"timestamp\":")
      in
      let jsons = List.map log_lines ~f:Yojson.Safe.from_string in
      let metadata_jsons =
        List.map jsons ~f:(fun json ->
            match Yojson.Safe.Util.member "metadata" json with
            | `Null ->
                failwithf "Log line is missing metadata: %s"
                  (Yojson.Safe.to_string json)
                  ()
            | md ->
                md )
      in
      let state_hash_and_blocks =
        List.fold metadata_jsons ~init:[] ~f:(fun acc json ->
            match Yojson.Safe.Util.member "precomputed_block" json with
            | `Null ->
                acc
            | `Assoc _ as block -> (
                match Yojson.Safe.Util.member "state_hash" json with
                | `String _ as state_hash ->
                    (state_hash, block) :: acc
                | _ ->
                    failwith
                      "Log metadata contains a precomputed block, but no state \
                       hash" )
            | other ->
                failwithf "Expected log line to be a JSON record, got: %s"
                  (Yojson.Safe.to_string other)
                  () )
      in
      let open Deferred.Let_syntax in
      let%bind () =
        Deferred.List.iter state_hash_and_blocks
          ~f:(fun (state_hash_json, block_json) ->
            let double_quoted_state_hash =
              Yojson.Safe.to_string state_hash_json
            in
            let state_hash =
              String.sub double_quoted_state_hash ~pos:1
                ~len:(String.length double_quoted_state_hash - 2)
            in
            let block = Yojson.Safe.pretty_to_string block_json in
            let filename = state_hash ^ ".json" in
            match%map Sys.file_exists filename with
            | `Yes ->
                [%log info]
                  "File already exists for precomputed block with state hash %s"
                  state_hash
            | _ ->
                [%log info]
                  "Dumping precomputed block with state hash %s to file %s"
                  state_hash filename ;
                Out_channel.with_file filename ~f:(fun out_ch ->
                    Out_channel.output_string out_ch block ) )
      in
      Malleable_error.return ()
    with Failure err -> Malleable_error.hard_error_string err
end

type t =
  { constants : Test_config.constants
  ; testnet_log_filter : string
  ; genesis_keypairs : Network_keypair.t Core.String.Map.t
        (* below values are given by CI *)
  ; seeds : Node.t Core.String.Map.t
  ; block_producers : Node.t Core.String.Map.t
  ; snark_coordinators : Node.t Core.String.Map.t
  ; snark_workers : Node.t Core.String.Map.t
  ; archive_nodes : Node.t Core.String.Map.t
  ; network_id : Network_id.t
  }

let id { network_id; _ } = network_id

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

let all_node_id t =
  let pods = all_pods t |> Core.Map.to_alist in
  List.fold pods ~init:[] ~f:(fun acc (_, node) -> node.node_id :: acc)

let[@warning "-27"] initialize_infra ~logger network = Malleable_error.return ()

open Core_kernel
open Async
open Integration_test_lib

let get_container_id service_id =
  let%bind cwd = Unix.getcwd () in
  let open Malleable_error.Let_syntax in
  let%bind container_ids =
    Deferred.bind ~f:Malleable_error.or_hard_error
      (Integration_test_lib.Util.run_cmd_or_error cwd "docker"
         [ "ps"; "-f"; sprintf "name=%s" service_id; "--quiet" ] )
  in
  let container_id_list = String.split container_ids ~on:'\n' in
  match container_id_list with
  | [] ->
      Malleable_error.hard_error_format "No container id found for service %s"
        service_id
  | raw_container_id :: _ ->
      return (String.strip raw_container_id)

let run_in_container ?(exit_code = 10) container_id ~cmd =
  let%bind.Deferred cwd = Unix.getcwd () in
  Integration_test_lib.Util.run_cmd_or_hard_error ~exit_code cwd "docker"
    ([ "exec"; container_id ] @ cmd)

module Node = struct
  type config =
    { network_keypair : Network_keypair.t option
    ; service_id : string
    ; postgres_connection_uri : string option
    ; graphql_port : int
    }

  type t = { config : config; mutable should_be_running : bool }

  let id { config; _ } = config.service_id

  let infra_id { config; _ } = config.service_id

  let should_be_running { should_be_running; _ } = should_be_running

  let network_keypair { config; _ } = config.network_keypair

  let get_ingress_uri node =
    Uri.make ~scheme:"http" ~host:"127.0.0.1" ~path:"/graphql"
      ~port:node.config.graphql_port ()

  let get_container_index_from_service_name service_name =
    match String.split_on_chars ~on:[ '_' ] service_name with
    | _ :: value :: _ ->
        value
    | _ ->
        failwith "get_container_index_from_service_name: bad service name"

  let dump_archive_data ~logger (t : t) ~data_file =
    let service_name = t.config.service_id in
    match t.config.postgres_connection_uri with
    | None ->
        failwith
          (sprintf "dump_archive_data: %s not an archive container" service_name)
    | Some postgres_uri ->
        let open Malleable_error.Let_syntax in
        let%bind container_id = get_container_id service_name in
        [%log info] "Dumping archive data from (node: %s, container: %s)"
          service_name container_id ;
        let%map data =
          run_in_container container_id
            ~cmd:[ "pg_dump"; "--create"; "--no-owner"; postgres_uri ]
        in
        [%log info] "Dumping archive data to file %s" data_file ;
        Out_channel.with_file data_file ~f:(fun out_ch ->
            Out_channel.output_string out_ch data )

  let get_logs_in_container container_id =
    let%bind.Deferred cwd = Unix.getcwd () in
    Integration_test_lib.Util.run_cmd_or_hard_error ~exit_code:13 cwd "docker"
      [ "logs"; container_id ]

  let dump_mina_logs ~logger (t : t) ~log_file =
    let open Malleable_error.Let_syntax in
    let%bind container_id = get_container_id t.config.service_id in
    [%log info] "Dumping mina logs from (node: %s, container: %s)"
      t.config.service_id container_id ;
    let%map logs = get_logs_in_container container_id in
    [%log info] "Dumping mina logs to file %s" log_file ;
    Out_channel.with_file log_file ~f:(fun out_ch ->
        Out_channel.output_string out_ch logs )

  let cp_string_to_container_file container_id ~str ~dest =
    let tmp_file, oc =
      Caml.Filename.open_temp_file ~temp_dir:Filename.temp_dir_name
        "integration_test_cp_string" ".tmp"
    in
    Out_channel.output_string oc str ;
    Out_channel.close oc ;
    let%bind cwd = Unix.getcwd () in
    let dest_file = sprintf "%s:%s" container_id dest in
    Integration_test_lib.Util.run_cmd_or_error cwd "docker"
      [ "cp"; tmp_file; dest_file ]

  let run_replayer ?(start_slot_since_genesis = 0) ~logger (t : t) =
    let open Malleable_error.Let_syntax in
    let%bind container_id = get_container_id t.config.service_id in
    [%log info] "Running replayer on (node: %s, container: %s)"
      t.config.service_id container_id ;
    let%bind accounts =
      run_in_container container_id
        ~cmd:[ "jq"; "-c"; ".ledger.accounts"; "/root/runtime_config.json" ]
    in
    let replayer_input =
      sprintf
        {| { "start_slot_since_genesis": %d,
             "genesis_ledger": { "accounts": %s, "add_genesis_winner": true }} |}
        start_slot_since_genesis accounts
    in
    let dest = "replayer-input.json" in
    let%bind archive_container_id = get_container_id "archive" in
    let%bind () =
      Deferred.bind ~f:Malleable_error.return
        (cp_string_to_container_file archive_container_id ~str:replayer_input
           ~dest )
      >>| ignore
    in
    let postgres_url = Option.value_exn t.config.postgres_connection_uri in
    run_in_container container_id
      ~cmd:
        [ "mina-replayer"
        ; "--archive-uri"
        ; postgres_url
        ; "--input-file"
        ; dest
        ; "--output-file"
        ; "/dev/null"
        ; "--log-json"
        ; "--continue-on-error"
        ]

  let dump_precomputed_blocks ~logger (t : t) =
    let open Malleable_error.Let_syntax in
    let container_id = t.config.service_id in
    [%log info]
      "Dumping precomputed blocks from logs for (node: %s, container: %s)"
      t.config.service_id container_id ;
    let%bind logs = get_logs_in_container container_id in
    (* kubectl logs may include non-log output, like "Using password from environment variable" *)
    let log_lines =
      String.split logs ~on:'\n'
      |> List.filter ~f:(String.is_prefix ~prefix:"{\"timestamp\":")
    in
    let jsons = List.map log_lines ~f:Yojson.Safe.from_string in
    let metadata_jsons =
      List.map jsons ~f:(fun json ->
          match json with
          | `Assoc items -> (
              match List.Assoc.find items ~equal:String.equal "metadata" with
              | Some md ->
                  md
              | None ->
                  failwithf "Log line is missing metadata: %s"
                    (Yojson.Safe.to_string json)
                    () )
          | other ->
              failwithf "Expected log line to be a JSON record, got: %s"
                (Yojson.Safe.to_string other)
                () )
    in
    let state_hash_and_blocks =
      List.fold metadata_jsons ~init:[] ~f:(fun acc json ->
          match json with
          | `Assoc items -> (
              match
                List.Assoc.find items ~equal:String.equal "precomputed_block"
              with
              | Some block -> (
                  match
                    List.Assoc.find items ~equal:String.equal "state_hash"
                  with
                  | Some state_hash ->
                      (state_hash, block) :: acc
                  | None ->
                      failwith
                        "Log metadata contains a precomputed block, but no \
                         state hash" )
              | None ->
                  acc )
          | other ->
              failwithf "Expected log line to be a JSON record, got: %s"
                (Yojson.Safe.to_string other)
                () )
    in
    let%bind.Deferred () =
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
          match%map.Deferred Sys.file_exists filename with
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

  let start ~fresh_state node : unit Malleable_error.t =
    let open Malleable_error.Let_syntax in
    let%bind container_id = get_container_id node.config.service_id in
    node.should_be_running <- true ;
    let%bind () =
      if fresh_state then
        run_in_container container_id ~cmd:[ "rm"; "-rf"; ".mina-config/*" ]
        >>| ignore
      else Malleable_error.return ()
    in
    run_in_container ~exit_code:11 container_id ~cmd:[ "/start.sh" ] >>| ignore

  let stop node =
    let open Malleable_error.Let_syntax in
    let%bind container_id = get_container_id node.config.service_id in
    node.should_be_running <- false ;
    run_in_container ~exit_code:12 container_id ~cmd:[ "/stop.sh" ] >>| ignore
end

module Service_to_deploy = struct
  type config =
    { network_keypair : Network_keypair.t option
    ; postgres_connection_uri : string option
    ; graphql_port : int
    }

  type t = { stack_name : string; service_name : string; config : config }

  let construct_service stack_name service_name config : t =
    { stack_name; service_name; config }

  let init_service_to_deploy_config ?(network_keypair = None)
      ?(postgres_connection_uri = None) ~graphql_port =
    { network_keypair; postgres_connection_uri; graphql_port }

  let get_node_from_service t =
    let open Malleable_error.Let_syntax in
    let service_id = sprintf "%s_%s" t.stack_name t.service_name in
    let%bind container_id = get_container_id service_id in
    if String.is_empty container_id then
      Malleable_error.hard_error_format "No container id found for service %s"
        t.service_name
    else
      return
        { Node.config =
            { service_id
            ; network_keypair = t.config.network_keypair
            ; postgres_connection_uri = t.config.postgres_connection_uri
            ; graphql_port = t.config.graphql_port
            }
        ; should_be_running = false
        }
end

type t =
  { namespace : string
  ; constants : Test_config.constants
  ; seeds : Node.t Core.String.Map.t
  ; block_producers : Node.t Core.String.Map.t
  ; snark_coordinators : Node.t Core.String.Map.t
  ; snark_workers : Node.t Core.String.Map.t
  ; archive_nodes : Node.t Core.String.Map.t
  ; genesis_keypairs : Network_keypair.t Core.String.Map.t
  }

let constants { constants; _ } = constants

let constraint_constants { constants; _ } = constants.constraints

let genesis_constants { constants; _ } = constants.genesis

let seeds { seeds; _ } = seeds

let block_producers { block_producers; _ } = block_producers

let snark_coordinators { snark_coordinators; _ } = snark_coordinators

let archive_nodes { archive_nodes; _ } = archive_nodes

let all_mina_nodes { seeds; block_producers; snark_coordinators; _ } =
  List.concat
    [ Core.String.Map.to_alist seeds
    ; Core.String.Map.to_alist block_producers
    ; Core.String.Map.to_alist snark_coordinators
    ]
  |> Core.String.Map.of_alist_exn

let all_nodes t =
  List.concat
    [ Core.String.Map.to_alist t.seeds
    ; Core.String.Map.to_alist t.block_producers
    ; Core.String.Map.to_alist t.snark_coordinators
    ; Core.String.Map.to_alist t.snark_workers
    ]
  |> Core.String.Map.of_alist_exn

let all_non_seed_nodes t =
  List.concat
    [ Core.String.Map.to_alist t.block_producers
    ; Core.String.Map.to_alist t.snark_coordinators
    ; Core.String.Map.to_alist t.snark_workers
    ]
  |> Core.String.Map.of_alist_exn

let genesis_keypairs { genesis_keypairs; _ } = genesis_keypairs

let all_ids t =
  let deployments = all_nodes t |> Core.Map.to_alist in
  List.fold deployments ~init:[] ~f:(fun acc (_, node) ->
      List.cons node.config.service_id acc )

let initialize_infra ~logger network =
  let _ = logger in
  let _ = network in
  Malleable_error.return ()

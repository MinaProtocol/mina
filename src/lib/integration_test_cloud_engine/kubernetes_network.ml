open Core_kernel
open Async
open Integration_test_lib

(* exclude from bisect_ppx to avoid type error on GraphQL modules *)
[@@@coverage exclude_file]

let mina_archive_container_id = "archive"

let mina_archive_username = "mina"

let mina_archive_pw = "zo3moong7moog4Iep7eNgo3iecaesahH"

let postgres_url =
  Printf.sprintf "postgres://%s:%s@archive-1-postgresql:5432/archive"
    mina_archive_username mina_archive_pw

type config =
  { testnet_name : string
  ; cluster : string
  ; namespace : string
  ; graphql_enabled : bool
  }

let base_kube_args { cluster; namespace; _ } =
  [ "--cluster"; cluster; "--namespace"; namespace ]

module Node = struct
  type pod_info =
    { network_keypair : Network_keypair.t option
    ; primary_container_id : string
          (* this is going to be probably either "mina" or "worker" *)
    ; has_archive_container : bool
          (* archive pods have a "mina" container and an "archive" container alongside *)
    }

  type t =
    { app_id : string
    ; pod_ids : string list
    ; pod_info : pod_info
    ; config : config
    }

  let id { pod_ids; _ } = List.hd_exn pod_ids

  let network_keypair { pod_info = { network_keypair; _ }; _ } = network_keypair

  let base_kube_args t = [ "--cluster"; t.cluster; "--namespace"; t.namespace ]

  let get_ingress_uri node =
    let host =
      Printf.sprintf "%s.graphql.test.o1test.net" node.config.testnet_name
    in
    let path = Printf.sprintf "/%s/graphql" node.app_id in
    Uri.make ~scheme:"http" ~host ~path ~port:80 ()

  let get_logs_in_container ?container_id { pod_ids; config; pod_info; _ } =
    let container_id =
      Option.value container_id ~default:pod_info.primary_container_id
    in
    let%bind cwd = Unix.getcwd () in
    Integration_test_lib.Util.run_cmd_or_hard_error ~exit_code:13 cwd "kubectl"
      ( base_kube_args config
      @ [ "logs"; "-c"; container_id; List.hd_exn pod_ids ] )

  let run_in_container ?(exit_code = 10) ?container_id ?override_with_pod_id
      ~cmd t =
    let { config; pod_info; _ } = t in
    let pod_id =
      match override_with_pod_id with
      | Some pid ->
          pid
      | None ->
          List.hd_exn t.pod_ids
    in
    let container_id =
      Option.value container_id ~default:pod_info.primary_container_id
    in
    let%bind cwd = Unix.getcwd () in
    Integration_test_lib.Util.run_cmd_or_hard_error ~exit_code cwd "kubectl"
      ( base_kube_args config
      @ [ "exec"; "-c"; container_id; "-i"; pod_id; "--" ]
      @ cmd )

  let cp_string_to_container_file ?container_id ~str ~dest t =
    let { pod_ids; config; pod_info; _ } = t in
    let container_id =
      Option.value container_id ~default:pod_info.primary_container_id
    in
    let tmp_file, oc =
      Caml.Filename.open_temp_file ~temp_dir:Filename.temp_dir_name
        "integration_test_cp_string" ".tmp"
    in
    Out_channel.output_string oc str ;
    Out_channel.close oc ;
    let%bind cwd = Unix.getcwd () in
    let dest_file =
      sprintf "%s/%s:%s" config.namespace (List.hd_exn pod_ids) dest
    in
    Integration_test_lib.Util.run_cmd_or_error cwd "kubectl"
      (base_kube_args config @ [ "cp"; "-c"; container_id; tmp_file; dest_file ])

  let start ~fresh_state node : unit Malleable_error.t =
    let open Malleable_error.Let_syntax in
    let%bind () =
      if fresh_state then
        run_in_container node ~cmd:[ "sh"; "-c"; "rm -rf .mina-config/*" ]
        >>| ignore
      else Malleable_error.return ()
    in
    run_in_container ~exit_code:11 node ~cmd:[ "/start.sh" ] >>| ignore

  let stop node =
    let open Malleable_error.Let_syntax in
    run_in_container ~exit_code:12 node ~cmd:[ "/stop.sh" ] >>| ignore

  let logger_infra_metadata node =
    [ ("namespace", `String node.config.namespace)
    ; ("app_id", `String node.app_id)
    ; ("pod_id", `String (List.hd_exn node.pod_ids))
    ]

  let dump_archive_data ~logger (t : t) ~data_file =
    (* this function won't work if `t` doesn't happen to be an archive node *)
    if not t.pod_info.has_archive_container then
      failwith
        "No archive container found.  One can only dump archive data of an \
         archive node." ;
    let open Malleable_error.Let_syntax in
    let postgresql_pod_id = t.app_id ^ "-postgresql-0" in
    let postgresql_container_id = "postgresql" in
    (* Some quick clarification on the archive nodes:
         An archive node archives all blocks as they come through, but does not produce blocks.
         An archive node uses postgresql as storage, the postgresql db needs to be separately brought up and is sort of it's own thing infra wise
         Archive nodes can be run side-by-side with an actual mina node

       in the integration test framework, every archive node will have it's own single postgresql instance.
       thus in the integration testing framework there will always be a one to one correspondence between archive node and postgresql db.
       however more generally, it's entirely possible for a mina user/operator set up multiple archive nodes to be backed by a single postgresql database.
       But for now we will assume that we don't need to test that

       The integration test framework creates kubenetes deployments or "workloads" as they are called in GKE, but Nodes are mainly tracked by pod_id

       A postgresql workload in the integration test framework will always have 1 managed pod,
         whose pod_id is simply the app id/workload name of the archive node appended with "-postgresql-0".
         so if the archive node is called "archive-1", then the corresponding postgresql managed pod will be called "archive-1-postgresql-0".
       That managed pod will have exactly 1 container, and it will be called simply "postgresql"

       It's rather hardcoded but this was just the simplest way to go, as our kubernetes_network tracks Nodes, ie MINA nodes.  a postgresql db is hard to account for
       It's possible to run pg_dump from the archive node instead of directly reaching out to the postgresql pod, and that's what we used to do but there were occasionally version mismatches between the pg_dump on the archive node and the postgresql on the postgresql db
    *)
    [%log info] "Dumping archive data from (node: %s, container: %s)"
      postgresql_pod_id postgresql_container_id ;
    let%map data =
      run_in_container t ~container_id:postgresql_container_id
        ~override_with_pod_id:postgresql_pod_id
        ~cmd:[ "pg_dump"; "--create"; "--no-owner"; postgres_url ]
    in
    [%log info] "Dumping archive data to file %s" data_file ;
    Out_channel.with_file data_file ~f:(fun out_ch ->
        Out_channel.output_string out_ch data )

  let run_replayer ~logger (t : t) =
    [%log info] "Running replayer on archived data (node: %s, container: %s)"
      (List.hd_exn t.pod_ids) mina_archive_container_id ;
    let open Malleable_error.Let_syntax in
    let%bind accounts =
      run_in_container t
        ~cmd:[ "jq"; "-c"; ".ledger.accounts"; "/root/config/daemon.json" ]
    in
    let replayer_input =
      sprintf
        {| { "genesis_ledger": { "accounts": %s, "add_genesis_winner": true }} |}
        accounts
    in
    let dest = "replayer-input.json" in
    let%bind _res =
      Deferred.bind ~f:Malleable_error.return
        (cp_string_to_container_file t ~container_id:mina_archive_container_id
           ~str:replayer_input ~dest )
    in
    run_in_container t ~container_id:mina_archive_container_id
      ~cmd:
        [ "mina-replayer"
        ; "--archive-uri"
        ; postgres_url
        ; "--input-file"
        ; dest
        ; "--output-file"
        ; "/dev/null"
        ; "--continue-on-error"
        ]

  let dump_mina_logs ~logger (t : t) ~log_file =
    let open Malleable_error.Let_syntax in
    [%log info] "Dumping container logs from (node: %s, container: %s)"
      (List.hd_exn t.pod_ids) t.pod_info.primary_container_id ;
    let%map logs = get_logs_in_container t in
    [%log info] "Dumping container log to file %s" log_file ;
    Out_channel.with_file log_file ~f:(fun out_ch ->
        Out_channel.output_string out_ch logs )

  let dump_precomputed_blocks ~logger (t : t) =
    let open Malleable_error.Let_syntax in
    [%log info]
      "Dumping precomputed blocks from logs for (node: %s, container: %s)"
      (List.hd_exn t.pod_ids) t.pod_info.primary_container_id ;
    let%bind logs = get_logs_in_container t in
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
end

module Workload_to_deploy = struct
  type t = { workload_id : string; pod_info : Node.pod_info }

  let construct_workload workload_id pod_info : t = { workload_id; pod_info }

  let cons_pod_info ?network_keypair ?(has_archive_container = false)
      primary_container_id : Node.pod_info =
    { network_keypair; has_archive_container; primary_container_id }

  let get_nodes_from_workload t ~config =
    let%bind cwd = Unix.getcwd () in
    let open Malleable_error.Let_syntax in
    let%bind app_id =
      Deferred.bind ~f:Malleable_error.or_hard_error
        (Integration_test_lib.Util.run_cmd_or_error cwd "kubectl"
           ( base_kube_args config
           @ [ "get"
             ; "deployment"
             ; t.workload_id
             ; "-o"
             ; "jsonpath={.spec.selector.matchLabels.app}"
             ] ) )
    in
    let%map pod_ids_str =
      Integration_test_lib.Util.run_cmd_or_hard_error cwd "kubectl"
        ( base_kube_args config
        @ [ "get"; "pod"; "-l"; "app=" ^ app_id; "-o"; "name" ] )
    in
    let pod_ids =
      String.split pod_ids_str ~on:'\n'
      |> List.filter ~f:(Fn.compose not String.is_empty)
      |> List.map ~f:(String.substr_replace_first ~pattern:"pod/" ~with_:"")
    in
    (* we have a strict 1 workload to 1 pod setup, except the snark workers. *)
    (* elsewhere in the code I'm simply using List.hd_exn which is not ideal but enabled by the fact that in all relevant cases, there's only going to be 1 pod id in pod_ids *)
    (* TODO fix this^ and have a more elegant solution *)
    let pod_info = t.pod_info in
    { Node.app_id; pod_ids; pod_info; config }
end

type t =
  { namespace : string
  ; constants : Test_config.constants
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

let lookup_node_by_pod_id t id =
  let pods = all_pods t |> Core.Map.to_alist in
  List.fold pods ~init:None ~f:(fun acc (node_name, node) ->
      match acc with
      | Some acc ->
          Some acc
      | None ->
          if String.equal id (List.hd_exn node.pod_ids) then
            Some (node_name, node)
          else None )

let all_pod_ids t =
  let pods = all_pods t |> Core.Map.to_alist in
  List.fold pods ~init:[] ~f:(fun acc (_, node) ->
      List.cons (List.hd_exn node.pod_ids) acc )

let initialize_infra ~logger network =
  let open Malleable_error.Let_syntax in
  let poll_interval = Time.Span.of_sec 15.0 in
  let max_polls = 40 (* 10 mins *) in
  let all_pods_set = all_pod_ids network |> String.Set.of_list in
  let kube_get_pods () =
    Integration_test_lib.Util.run_cmd_or_error_timeout ~timeout_seconds:60 "/"
      "kubectl"
      [ "-n"
      ; network.namespace
      ; "get"
      ; "pods"
      ; "-ojsonpath={range \
         .items[*]}{.metadata.name}{':'}{.status.phase}{'\\n'}{end}"
      ]
  in
  let parse_pod_statuses result_str =
    result_str |> String.split_lines
    |> List.map ~f:(fun line ->
           let parts = String.split line ~on:':' in
           assert (Mina_stdlib.List.Length.Compare.(parts = 2)) ;
           (List.nth_exn parts 0, List.nth_exn parts 1) )
    |> List.filter ~f:(fun (pod_name, _) ->
           String.Set.mem all_pods_set pod_name )
    (* this filters out the archive bootstrap pods, since they aren't in all_pods_set.  in fact the bootstrap pods aren't tracked at all in the framework *)
    |> String.Map.of_alist_exn
  in
  let rec poll n =
    [%log debug] "Checking kubernetes pod statuses, n=%d" n ;
    let is_successful_pod_status status = String.equal "Running" status in
    match%bind Deferred.bind ~f:Malleable_error.return (kube_get_pods ()) with
    | Ok str ->
        let pod_statuses = parse_pod_statuses str in
        [%log debug] "pod_statuses: \n %s"
          ( String.Map.to_alist pod_statuses
          |> List.map ~f:(fun (key, data) -> key ^ ": " ^ data ^ "\n")
          |> String.concat ) ;
        [%log debug] "all_pods: \n %s"
          (String.Set.elements all_pods_set |> String.concat ~sep:", ") ;
        let all_pods_are_present =
          List.for_all (String.Set.elements all_pods_set) ~f:(fun pod_id ->
              String.Map.mem pod_statuses pod_id )
        in
        let any_pods_are_not_running =
          (* there could be duplicate keys... *)
          List.exists
            (String.Map.data pod_statuses)
            ~f:(Fn.compose not is_successful_pod_status)
        in
        if not all_pods_are_present then (
          let present_pods = String.Map.keys pod_statuses in
          [%log fatal]
            "Not all pods were found when querying namespace; this indicates a \
             deployment error. Refusing to continue. \n\
             Expected pods: [%s].  \n\
             Present pods: [%s]"
            (String.Set.elements all_pods_set |> String.concat ~sep:"; ")
            (present_pods |> String.concat ~sep:"; ") ;
          Malleable_error.hard_error_string ~exit_code:5
            "Some pods were not found in namespace." )
        else if any_pods_are_not_running then
          let failed_pod_statuses =
            List.filter (String.Map.to_alist pod_statuses)
              ~f:(fun (_, status) -> not (is_successful_pod_status status))
          in
          if n > 0 then (
            [%log debug] "Got bad pod statuses, polling again ($failed_statuses"
              ~metadata:
                [ ( "failed_statuses"
                  , `Assoc
                      (List.Assoc.map failed_pod_statuses ~f:(fun v ->
                           `String v ) ) )
                ] ;
            let%bind () =
              after poll_interval |> Deferred.bind ~f:Malleable_error.return
            in
            poll (n - 1) )
          else (
            [%log fatal]
              "Got bad pod statuses, not all pods were assigned to nodes and \
               ready in time.  pod statuses: ($failed_statuses"
              ~metadata:
                [ ( "failed_statuses"
                  , `Assoc
                      (List.Assoc.map failed_pod_statuses ~f:(fun v ->
                           `String v ) ) )
                ] ;
            Malleable_error.hard_error_string ~exit_code:4
              "Some pods either were not assigned to nodes or did not deploy \
               properly." )
        else return ()
    | Error _ ->
        [%log debug] "`kubectl get pods` timed out, polling again" ;
        let%bind () =
          after poll_interval |> Deferred.bind ~f:Malleable_error.return
        in
        poll n
  in
  [%log info] "Waiting for pods to be assigned nodes and become ready" ;
  let res = poll max_polls in
  match%bind.Deferred res with
  | Error _ ->
      [%log error] "Not all pods were assigned nodes, cannot proceed!" ;
      res
  | Ok _ ->
      [%log info] "Pods assigned to nodes" ;
      res

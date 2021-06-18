open Core
open Async
open Integration_test_lib

(* exclude from bisect_ppx to avoid type error on GraphQL modules *)
[@@@coverage exclude_file]

module Node = struct
  type t =
    { swarm_name : string
    ; service_id : string
    ; graphql_enabled : bool
    ; network_keypair : Network_keypair.t option
    }

  let id { service_id; _ } = service_id

  let network_keypair { network_keypair; _ } = network_keypair

  let get_container_cmd t =
    Printf.sprintf "$(docker ps -f name=%s --quiet)" t.service_id

  let run_in_postgresql_container _ _ = failwith "run_in_postgresql_container"

  let get_logs_in_container _ = failwith "get_logs_in_container"

  let run_in_container node cmd =
    let base_docker_cmd = "docker exec" in
    let docker_cmd =
      Printf.sprintf "%s %s %s" base_docker_cmd (get_container_cmd node) cmd
    in
    let%bind.Deferred cwd = Unix.getcwd () in
    Malleable_error.return (Util.run_cmd_exn cwd "sh" [ "-c"; docker_cmd ])

  let start ~fresh_state node : unit Malleable_error.t =
    let open Malleable_error.Let_syntax in
    let%bind _ =
      Deferred.bind ~f:Malleable_error.return (run_in_container node "ps aux")
    in
    let%bind () =
      if fresh_state then
        let%bind _ = run_in_container node "rm -rf .mina-config/*" in
        Malleable_error.return ()
      else Malleable_error.return ()
    in
    let cmd =
      match String.substr_index node.service_id ~pattern:"snark-worker" with
      | Some _ ->
          (* Snark-workers should wait for work to be generated so they don't error a 'get_work' RPC call*)
          "/bin/bash -c 'sleep 120 && ./start.sh'"
      | None ->
          "./start.sh"
    in
    let%bind _ = run_in_container node cmd in
    Malleable_error.return ()

  let stop node =
    let open Malleable_error.Let_syntax in
    let%bind _ = run_in_container node "ps aux" in
    let%bind _ = run_in_container node "./stop.sh" in
    let%bind _ = run_in_container node "ps aux" in
    return ()

  module Decoders = Graphql_lib.Decoders

  let exec_graphql_request ~num_tries:_ ~retry_delay_sec:_ ~initial_delay_sec:_
      ~logger:_ ~node:_ ~query_name:_ _ : _ =
    failwith "exec_graphql_request"

  let get_peer_id ~logger:_ _ = failwith "get_peer_id"

  let must_get_peer_id ~logger:_ _ = failwith "must_get_peer_id"

  let get_best_chain ~logger:_ _ = failwith "get_best_chain"

  let must_get_best_chain ~logger:_ _ = failwith "must_get_best_chain"

  let get_balance ~logger:_ _ ~account_id:_ = failwith "get_balance"

  let must_get_balance ~logger t ~account_id =
    get_balance ~logger t ~account_id
    |> Deferred.bind ~f:Malleable_error.or_hard_error

  (* if we expect failure, might want retry_on_graphql_error to be false *)
  let send_payment ~logger:_ _ ~sender_pub_key:_ ~receiver_pub_key:_ ~amount:_
      ~fee:_ =
    failwith "send_payment"

  let must_send_payment ~logger t ~sender_pub_key ~receiver_pub_key ~amount ~fee
      =
    send_payment ~logger t ~sender_pub_key ~receiver_pub_key ~amount ~fee
    |> Deferred.bind ~f:Malleable_error.or_hard_error

  let dump_archive_data ~logger:_ (_ : t) ~data_file:_ =
    failwith "dump_archive_data"

  let dump_container_logs ~logger:_ (_ : t) ~log_file:_ =
    Malleable_error.return ()

  let dump_precomputed_blocks ~logger:_ (_ : t) = Malleable_error.return ()
end

type t =
  { namespace : string
  ; constants : Test_config.constants
  ; seeds : Node.t list
  ; block_producers : Node.t list
  ; snark_coordinators : Node.t list
  ; archive_nodes : Node.t list
  ; testnet_log_filter : string
  ; keypairs : Signature_lib.Keypair.t list
  ; nodes_by_app_id : Node.t String.Map.t
  }

let constants { constants; _ } = constants

let constraint_constants { constants; _ } = constants.constraints

let genesis_constants { constants; _ } = constants.genesis

let seeds { seeds; _ } = seeds

let block_producers { block_producers; _ } = block_producers

let snark_coordinators { snark_coordinators; _ } = snark_coordinators

let archive_nodes { archive_nodes; _ } = archive_nodes

let keypairs { keypairs; _ } = keypairs

let all_nodes { seeds; block_producers; snark_coordinators; archive_nodes; _ } =
  List.concat [ seeds; block_producers; snark_coordinators; archive_nodes ]

let lookup_node_by_app_id t = Map.find t.nodes_by_app_id

let initialize ~logger network =
  Print.print_endline "initialize" ;
  let open Malleable_error.Let_syntax in
  let poll_interval = Time.Span.of_sec 15.0 in
  let max_polls = 60 (* 15 mins *) in
  let all_services =
    all_nodes network
    |> List.map ~f:(fun { service_id; _ } -> service_id)
    |> String.Set.of_list
  in
  let get_service_statuses () =
    let%map output =
      Deferred.bind ~f:Malleable_error.return
        (Util.run_cmd_exn "/" "docker"
           [ "service"; "ls"; "--format"; "{{.Name}}: {{.Replicas}}" ])
    in
    output |> String.split_lines
    |> List.map ~f:(fun line ->
           let parts = String.split line ~on:':' in
           assert (List.length parts = 2) ;
           (List.nth_exn parts 0, List.nth_exn parts 1))
    |> List.filter ~f:(fun (service_name, _) ->
           String.Set.mem all_services service_name)
  in
  let rec poll n =
    let%bind pod_statuses = get_service_statuses () in
    (* TODO: detect "bad statuses" (eg CrashLoopBackoff) and terminate early *)
    let bad_service_statuses =
      List.filter pod_statuses ~f:(fun (_, status) ->
          let parts = String.split status ~on:'/' in
          assert (List.length parts = 2) ;
          let num, denom =
            ( String.strip (List.nth_exn parts 0)
            , String.strip (List.nth_exn parts 1) )
          in
          not (String.equal num denom))
    in
    if List.is_empty bad_service_statuses then return ()
    else if n < max_polls then
      let%bind () =
        after poll_interval |> Deferred.bind ~f:Malleable_error.return
      in
      poll (n + 1)
    else
      let bad_service_statuses_json =
        `List
          (List.map bad_service_statuses ~f:(fun (service_name, status) ->
               `Assoc
                 [ ("service_name", `String service_name)
                 ; ("status", `String status)
                 ]))
      in
      [%log fatal]
        "Not all services could be deployed in time: $bad_service_statuses"
        ~metadata:[ ("bad_service_statuses", bad_service_statuses_json) ] ;
      Malleable_error.hard_error_format
        "Some services either were not deployed properly (errors: %s)"
        (Yojson.Safe.to_string bad_service_statuses_json)
  in
  [%log info] "Waiting for pods to be assigned nodes and become ready" ;
  Deferred.bind (poll 0) ~f:(fun res ->
      if Malleable_error.is_ok res then
        let seed_nodes = seeds network in
        let seed_pod_ids =
          seed_nodes
          |> List.map ~f:(fun { Node.service_id; _ } -> service_id)
          |> String.Set.of_list
        in
        let non_seed_nodes =
          network |> all_nodes
          |> List.filter ~f:(fun { Node.service_id; _ } ->
                 not (String.Set.mem seed_pod_ids service_id))
        in
        (* TODO: parallelize (requires accumlative hard errors) *)
        let%bind () =
          Malleable_error.List.iter seed_nodes
            ~f:(Node.start ~fresh_state:false)
        in
        (* put a short delay before starting other nodes, to help avoid artifact generation races *)
        let%bind () =
          after (Time.Span.of_sec 30.0)
          |> Deferred.bind ~f:Malleable_error.return
        in
        Malleable_error.List.iter non_seed_nodes
          ~f:(Node.start ~fresh_state:false)
      else Deferred.return res)

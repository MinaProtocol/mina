open Async
open Core
open Pipe_lib

type catchup_job_states =
  (Transition_frontier.Full_catchup_tree.Node.State.Enum.t * int) list option
[@@deriving to_yojson]

type rpc_count =
  { get_some_initial_peers : float
  ; get_staged_ledger_aux_and_pending_coinbases_at_hash : float
  ; answer_sync_ledger_query : float
  ; get_transition_chain : float
  ; get_transition_knowledge : float
  ; get_transition_chain_proof : float
  ; get_node_status : float
  ; get_ancestry : float
  ; ban_notify : float
  ; get_best_tip : float
  ; get_epoch_ledger : float
  }
[@@deriving to_yojson]

type node_status_data =
  { block_height_at_best_tip : int
  ; max_observed_block_height : int
  ; max_observed_unvalidated_block_height : int
  ; catchup_job_states : catchup_job_states
  ; sync_status : Sync_status.Stable.V1.t
  ; libp2p_input_bandwidth : float
  ; libp2p_output_bandwidth : float
  ; libp2p_cpu_usage : float
  ; commit_hash : string
  ; git_branch : string
  ; peer_id : string
  ; ip_address : string
  ; timestamp : string
  ; uptime_of_node : float
  ; peer_count : int
  ; rpc_received : rpc_count
  ; rpc_sent : rpc_count
  }
[@@deriving to_yojson]

let send_node_status_data ~logger ~url node_status_data =
  let node_status_json = node_status_data_to_yojson node_status_data in
  let json = `Assoc [ ("data", node_status_json) ] in
  let headers =
    Cohttp.Header.of_list [ ("Content-Type", "application/json") ]
  in
  match%map
    Cohttp_async.Client.post ~headers
      ~body:(Yojson.Safe.to_string json |> Cohttp_async.Body.of_string)
      url
  with
  | { status; _ }, body ->
      let metadata =
        [ ("data", node_status_json); ("url", `String (Uri.to_string url)) ]
      in
      if Cohttp.Code.code_of_status status = 200 then
        [%log info] "Sent node status data to URL $url" ~metadata
      else
        let extra_metadata =
          match body with
          | `String s ->
              [ ("error", `String s) ]
          | `Strings ss ->
              [ ("error", `List (List.map ss ~f:(fun s -> `String s))) ]
          | `Empty | `Pipe _ ->
              []
        in
        [%log error] "Failed to send node status data to URL $url"
          ~metadata:(metadata @ extra_metadata)

let start ~logger ~node_status_url ~transition_frontier ~sync_status ~network
    ~addrs_and_ports ~start_time =
  let url_string = Option.value ~default:"127.0.0.1" node_status_url in
  [%log info] "Starting node status service using URL $url"
    ~metadata:[ ("URL", `String url_string) ] ;

  don't_wait_for
  @@
  match Broadcast_pipe.Reader.peek transition_frontier with
  | None ->
      [%log info] "Transition frontier not available for node status service" ;
      Deferred.unit
  | Some tf -> (
      let catchup_job_states =
        match Transition_frontier.catchup_tree tf with
        | Full catchup_tree ->
            Some
              (Transition_frontier.Full_catchup_tree.to_node_status_report
                 catchup_tree)
        | _ ->
            None
      in
      let sync_status =
        sync_status |> Mina_incremental.Status.Observer.value_exn
      in
      match%bind Mina_networking.bandwidth_info network with
      | Ok
          ( `Input libp2p_input_bandwidth
          , `Output libp2p_output_bandwidth
          , `Cpu_usage libp2p_cpu_usage ) ->
          let%bind peers = Mina_networking.peers network in
          let node_status_data =
            { block_height_at_best_tip =
                Transition_frontier.best_tip tf
                |> Transition_frontier.Breadcrumb.blockchain_length
                |> Unsigned.UInt32.to_int
            ; max_observed_block_height =
                !Mina_metrics.Transition_frontier.max_blocklength_observed
            ; max_observed_unvalidated_block_height =
                !Mina_metrics.Transition_frontier
                 .max_unvalidated_blocklength_observed
            ; catchup_job_states
            ; sync_status
            ; libp2p_input_bandwidth
            ; libp2p_output_bandwidth
            ; libp2p_cpu_usage
            ; commit_hash = Mina_version.commit_id
            ; git_branch = Mina_version.branch
            ; peer_id =
                (Node_addrs_and_ports.to_peer_exn addrs_and_ports).peer_id
            ; ip_address =
                Node_addrs_and_ports.external_ip addrs_and_ports
                |> Core.Unix.Inet_addr.to_string
            ; timestamp = Rfc3339_time.get_rfc3339_time ()
            ; uptime_of_node =
                Time.Span.to_sec @@ Time.diff (Time.now ()) start_time
            ; peer_count = List.length peers
            ; rpc_sent =
                { get_some_initial_peers =
                    Prometheus.Counter.value
                      Mina_metrics.Network.get_some_initial_peers_rpcs_sent
                ; get_staged_ledger_aux_and_pending_coinbases_at_hash =
                    Prometheus.Counter.value
                      Mina_metrics.Network
                      .get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_sent
                ; answer_sync_ledger_query =
                    Prometheus.Counter.value
                      Mina_metrics.Network.answer_sync_ledger_query_rpcs_sent
                ; get_transition_chain =
                    Prometheus.Counter.value
                      Mina_metrics.Network.get_transition_chain_proof_rpcs_sent
                ; get_transition_knowledge =
                    Prometheus.Counter.value
                      Mina_metrics.Network.get_transition_knowledge_rpcs_sent
                ; get_transition_chain_proof =
                    Prometheus.Counter.value
                      Mina_metrics.Network.get_transition_chain_proof_rpcs_sent
                ; get_node_status =
                    Prometheus.Counter.value
                      Mina_metrics.Network.get_node_status_rpcs_sent
                ; get_ancestry =
                    Prometheus.Counter.value
                      Mina_metrics.Network.get_ancestry_rpcs_sent
                ; ban_notify =
                    Prometheus.Counter.value
                      Mina_metrics.Network.ban_notify_rpcs_sent
                ; get_best_tip =
                    Prometheus.Counter.value
                      Mina_metrics.Network.get_best_tip_rpcs_sent
                ; get_epoch_ledger =
                    Prometheus.Counter.value
                      Mina_metrics.Network.get_epoch_ledger_rpcs_sent
                }
            ; rpc_received =
                { get_some_initial_peers =
                    Prometheus.Counter.value
                      Mina_metrics.Network.get_some_initial_peers_rpcs_received
                ; get_staged_ledger_aux_and_pending_coinbases_at_hash =
                    Prometheus.Counter.value
                      Mina_metrics.Network
                      .get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_received
                ; answer_sync_ledger_query =
                    Prometheus.Counter.value
                      Mina_metrics.Network
                      .answer_sync_ledger_query_rpcs_received
                ; get_transition_chain =
                    Prometheus.Counter.value
                      Mina_metrics.Network
                      .get_transition_chain_proof_rpcs_received
                ; get_transition_knowledge =
                    Prometheus.Counter.value
                      Mina_metrics.Network
                      .get_transition_knowledge_rpcs_received
                ; get_transition_chain_proof =
                    Prometheus.Counter.value
                      Mina_metrics.Network
                      .get_transition_chain_proof_rpcs_received
                ; get_node_status =
                    Prometheus.Counter.value
                      Mina_metrics.Network.get_node_status_rpcs_received
                ; get_ancestry =
                    Prometheus.Counter.value
                      Mina_metrics.Network.get_ancestry_rpcs_received
                ; ban_notify =
                    Prometheus.Counter.value
                      Mina_metrics.Network.ban_notify_rpcs_received
                ; get_best_tip =
                    Prometheus.Counter.value
                      Mina_metrics.Network.get_best_tip_rpcs_received
                ; get_epoch_ledger =
                    Prometheus.Counter.value
                      Mina_metrics.Network.get_epoch_ledger_rpcs_received
                }
            }
          in
          send_node_status_data ~logger ~url:(Uri.of_string url_string)
            node_status_data
      | Error e ->
          [%log info]
            ~metadata:[ ("error", `String (Error.to_string_hum e)) ]
            "Failed to get bandwidth info from libp2p" ;
          Deferred.unit )

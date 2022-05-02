open Async
open Core
open Pipe_lib

type catchup_job_states = Transition_frontier.Full_catchup_tree.job_states =
  { finished : int
  ; failed : int
  ; to_download : int
  ; to_initial_validate : int
  ; wait_for_parent : int
  ; to_verify : int
  ; to_build_breadcrumb : int
  }
[@@deriving to_yojson]

type rpc_count =
  { get_some_initial_peers : int
  ; get_staged_ledger_aux_and_pending_coinbases_at_hash : int
  ; answer_sync_ledger_query : int
  ; get_transition_chain : int
  ; get_transition_knowledge : int
  ; get_transition_chain_proof : int
  ; get_node_status : int
  ; get_ancestry : int
  ; ban_notify : int
  ; get_best_tip : int
  ; get_epoch_ledger : int
  }
[@@deriving to_yojson]

type gossip_count =
  { new_state : int; transaction_pool_diff : int; snark_pool_diff : int }
[@@deriving to_yojson]

type block =
  { hash : Mina_base.State_hash.t
  ; sender : Network_peer.Envelope.Sender.t
  ; received_at : string
  ; is_valid : bool
  ; reason_for_rejection :
      [ `Invalid_proof
      | `Invalid_delta_transition_chain_proof
      | `Too_early
      | `Too_late
      | `Invalid_genesis_protocol_state
      | `Invalid_protocol_version
      | `Mismatched_protocol_version ]
      option
  }
[@@deriving to_yojson]

type node_status_data =
  { version : int
  ; block_height_at_best_tip : int
  ; max_observed_block_height : int
  ; max_observed_unvalidated_block_height : int
  ; catchup_job_states : catchup_job_states option
  ; sync_status : Sync_status.t
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
  ; pubsub_msg_received : gossip_count
  ; pubsub_msg_broadcasted : gossip_count
  ; received_blocks : block list
  }
[@@deriving to_yojson]

let send_node_status_data ~logger ~url node_status_data =
  let node_status_json = node_status_data_to_yojson node_status_data in
  let json = `Assoc [ ("data", node_status_json) ] in
  let headers =
    Cohttp.Header.of_list [ ("Content-Type", "application/json") ]
  in
  match%map
    Async.try_with (fun () ->
        Cohttp_async.Client.post ~headers
          ~body:(Yojson.Safe.to_string json |> Cohttp_async.Body.of_string)
          url)
  with
  | Ok ({ status; _ }, body) ->
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
  | Error e ->
      [%log error] "Failed to send node status data to URL $url"
        ~metadata:
          [ ("error", `String (Exn.to_string e))
          ; ("url", `String (Uri.to_string url))
          ]

let reset_gauges () =
  let gauges =
    let open Mina_metrics.Network in
    [ new_state_received
    ; new_state_broadcasted
    ; transaction_pool_diff_received
    ; transaction_pool_diff_broadcasted
    ; snark_pool_diff_received
    ; snark_pool_diff_broadcasted
    ]
    @ List.map ~f:snd
        [ get_some_initial_peers_rpcs_sent
        ; get_some_initial_peers_rpcs_received
        ; get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_sent
        ; get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_received
        ; answer_sync_ledger_query_rpcs_sent
        ; answer_sync_ledger_query_rpcs_received
        ; get_transition_chain_rpcs_sent
        ; get_transition_chain_rpcs_received
        ; get_transition_knowledge_rpcs_sent
        ; get_transition_knowledge_rpcs_received
        ; get_transition_chain_proof_rpcs_sent
        ; get_transition_chain_proof_rpcs_received
        ; get_node_status_rpcs_sent
        ; get_node_status_rpcs_received
        ; get_ancestry_rpcs_sent
        ; get_ancestry_rpcs_received
        ; ban_notify_rpcs_sent
        ; ban_notify_rpcs_received
        ; get_best_tip_rpcs_sent
        ; get_best_tip_rpcs_received
        ; get_epoch_ledger_rpcs_sent
        ; get_epoch_ledger_rpcs_received
        ]
  in
  List.iter ~f:(fun gauge -> Mina_metrics.Gauge.set gauge 0.) gauges ;
  Queue.clear Transition_frontier.validated_blocks ;
  Queue.clear Transition_frontier.rejected_blocks

let start ~logger ~node_status_url ~transition_frontier ~sync_status ~network
    ~addrs_and_ports ~start_time ~slot_duration =
  [%log info] "Starting node status service using URL $url"
    ~metadata:[ ("url", `String node_status_url) ] ;
  let five_slots = Time.Span.scale slot_duration 5. in
  reset_gauges () ;
  every ~start:(after five_slots) ~continue_on_error:true five_slots
  @@ fun () ->
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
      [%log info] "About to send bandwidth request to libp2p" ;
      match%bind Mina_networking.bandwidth_info network with
      | Ok
          ( `Input libp2p_input_bandwidth
          , `Output libp2p_output_bandwidth
          , `Cpu_usage libp2p_cpu_usage ) ->
          let%bind peers = Mina_networking.peers network in
          let node_status_data =
            { version = 1
            ; block_height_at_best_tip =
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
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd Mina_metrics.Network.get_some_initial_peers_rpcs_sent
                ; get_staged_ledger_aux_and_pending_coinbases_at_hash =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd
                         Mina_metrics.Network
                         .get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_sent
                ; answer_sync_ledger_query =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd
                         Mina_metrics.Network.answer_sync_ledger_query_rpcs_sent
                ; get_transition_chain =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd
                         Mina_metrics.Network
                         .get_transition_chain_proof_rpcs_sent
                ; get_transition_knowledge =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd
                         Mina_metrics.Network.get_transition_knowledge_rpcs_sent
                ; get_transition_chain_proof =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd
                         Mina_metrics.Network
                         .get_transition_chain_proof_rpcs_sent
                ; get_node_status =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd Mina_metrics.Network.get_node_status_rpcs_sent
                ; get_ancestry =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd Mina_metrics.Network.get_ancestry_rpcs_sent
                ; ban_notify =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd Mina_metrics.Network.ban_notify_rpcs_sent
                ; get_best_tip =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd Mina_metrics.Network.get_best_tip_rpcs_sent
                ; get_epoch_ledger =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd Mina_metrics.Network.get_epoch_ledger_rpcs_sent
                }
            ; rpc_received =
                { get_some_initial_peers =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd
                         Mina_metrics.Network
                         .get_some_initial_peers_rpcs_received
                ; get_staged_ledger_aux_and_pending_coinbases_at_hash =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd
                         Mina_metrics.Network
                         .get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_received
                ; answer_sync_ledger_query =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd
                         Mina_metrics.Network
                         .answer_sync_ledger_query_rpcs_received
                ; get_transition_chain =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd
                         Mina_metrics.Network
                         .get_transition_chain_proof_rpcs_received
                ; get_transition_knowledge =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd
                         Mina_metrics.Network
                         .get_transition_knowledge_rpcs_received
                ; get_transition_chain_proof =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd
                         Mina_metrics.Network
                         .get_transition_chain_proof_rpcs_received
                ; get_node_status =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd Mina_metrics.Network.get_node_status_rpcs_received
                ; get_ancestry =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd Mina_metrics.Network.get_ancestry_rpcs_received
                ; ban_notify =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd Mina_metrics.Network.ban_notify_rpcs_received
                ; get_best_tip =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd Mina_metrics.Network.get_best_tip_rpcs_received
                ; get_epoch_ledger =
                    Float.to_int @@ Mina_metrics.Gauge.value
                    @@ snd Mina_metrics.Network.get_epoch_ledger_rpcs_received
                }
            ; pubsub_msg_received =
                { new_state =
                    Float.to_int
                    @@ Mina_metrics.Gauge.value
                         Mina_metrics.Network.new_state_received
                ; transaction_pool_diff =
                    Float.to_int
                    @@ Mina_metrics.Gauge.value
                         Mina_metrics.Network.transaction_pool_diff_received
                ; snark_pool_diff =
                    Float.to_int
                    @@ Mina_metrics.Gauge.value
                         Mina_metrics.Network.snark_pool_diff_received
                }
            ; pubsub_msg_broadcasted =
                { new_state =
                    Float.to_int
                    @@ Mina_metrics.Gauge.value
                         Mina_metrics.Network.new_state_broadcasted
                ; transaction_pool_diff =
                    Float.to_int
                    @@ Mina_metrics.Gauge.value
                         Mina_metrics.Network.transaction_pool_diff_broadcasted
                ; snark_pool_diff =
                    Float.to_int
                    @@ Mina_metrics.Gauge.value
                         Mina_metrics.Network.snark_pool_diff_broadcasted
                }
            ; received_blocks =
                List.map (Queue.to_list Transition_frontier.rejected_blocks)
                  ~f:(fun (hash, sender, received_at, reason_for_rejection) ->
                    { hash
                    ; sender
                    ; received_at =
                        Time.to_string (Block_time.to_time received_at)
                    ; is_valid = false
                    ; reason_for_rejection = Some reason_for_rejection
                    })
                @ List.map (Queue.to_list Transition_frontier.validated_blocks)
                    ~f:(fun (hash, sender, received_at) ->
                      { hash
                      ; sender
                      ; received_at =
                          Time.to_string (Block_time.to_time received_at)
                      ; is_valid = true
                      ; reason_for_rejection = None
                      })
            }
          in
          reset_gauges () ;
          send_node_status_data ~logger
            ~url:(Uri.of_string node_status_url)
            node_status_data
      | Error e ->
          [%log info]
            ~metadata:[ ("error", `String (Error.to_string_hum e)) ]
            "Failed to get bandwidth info from libp2p" ;
          Deferred.unit )

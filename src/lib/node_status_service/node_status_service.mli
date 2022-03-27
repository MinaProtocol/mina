type catchup_job_states = Transition_frontier.Full_catchup_tree.job_states =
  { finished : int
  ; failed : int
  ; to_download : int
  ; to_initial_validate : int
  ; wait_for_parent : int
  ; to_verify : int
  ; to_build_breadcrumb : int
  }

val catchup_job_states_to_yojson : catchup_job_states -> Yojson.Safe.t

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

val rpc_count_to_yojson : rpc_count -> Yojson.Safe.t

type gossip_count =
  { new_state : int; transaction_pool_diff : int; snark_pool_diff : int }

val gossip_count_to_yojson : gossip_count -> Yojson.Safe.t

type block =
  { hash : Mina_base.State_hash.t
  ; sender : Network_peer.Envelope.Sender.t
  ; received_at : string
  ; is_valid : bool
  ; reason_for_rejection :
      [ `Invalid_delta_transition_chain_proof
      | `Invalid_genesis_protocol_state
      | `Invalid_proof
      | `Invalid_protocol_version
      | `Mismatched_protocol_version
      | `Too_early
      | `Too_late ]
      option
  }

val block_to_yojson : block -> Yojson.Safe.t

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

val node_status_data_to_yojson : node_status_data -> Yojson.Safe.t

val send_node_status_data :
     logger:Logger.t
  -> url:Uri.t
  -> node_status_data
  -> unit Async_kernel__Deferred.t

val reset_gauges : unit -> unit

val start :
     logger:Logger.t
  -> node_status_url:string
  -> transition_frontier:
       Transition_frontier.t option Pipe_lib.Broadcast_pipe.Reader.t
  -> sync_status:Sync_status.t Mina_incremental.Status.Observer.t
  -> network:Mina_networking.t
  -> addrs_and_ports:Node_addrs_and_ports.t
  -> start_time:Core.Time.t
  -> slot_duration:Core.Time.Span.t
  -> unit

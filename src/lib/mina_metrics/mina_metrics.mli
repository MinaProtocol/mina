val time_offset_sec : float

module Counter : sig
  type t

  val inc_one : t -> unit

  val inc : t -> float -> unit
end

module Gauge : sig
  type t

  val inc_one : t -> unit

  val inc : t -> float -> unit

  val dec_one : t -> unit

  val dec : t -> float -> unit

  val set : t -> float -> unit
end

module type Histogram = sig
  type t

  val observe : t -> float -> unit

  val time : t -> (unit -> float) -> (unit -> 'a Lwt.t) -> 'a Lwt.t
end

module Runtime : sig
  val gc_stat_interval_mins : float ref

  module Long_async_histogram : Histogram

  val long_async_cycle : Long_async_histogram.t

  module Long_job_histogram : Histogram

  val long_async_job : Long_job_histogram.t
end

module Cryptography : sig
  val blockchain_proving_time_ms : Gauge.t

  val total_pedersen_hashes_computed : Counter.t

  module Snark_work_histogram : Histogram

  val snark_work_merge_time_sec : Snark_work_histogram.t

  val snark_work_base_time_sec : Snark_work_histogram.t
end

module Bootstrap : sig
  val bootstrap_time_ms : Gauge.t
end

module Transaction_pool : sig
  val useful_transactions_received_time_sec : Gauge.t

  val pool_size : Gauge.t
end

module Network : sig
  val peers : Gauge.t

  val all_peers : Gauge.t

  val gossip_messages_received : Counter.t

  val rpc_requests_received : Counter.t

  val rpc_requests_sent : Counter.t

  val get_some_initial_peers_rpcs_sent : Counter.t

  val get_some_initial_peers_rpcs_received : Counter.t

  val get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_sent : Counter.t

  val get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_received :
    Counter.t

  val answer_sync_ledger_query_rpcs_sent : Counter.t

  val answer_sync_ledger_query_rpcs_received : Counter.t

  val get_transition_chain_rpcs_sent : Counter.t

  val get_transition_chain_rpcs_received : Counter.t

  val get_transition_knowledge_rpcs_sent : Counter.t

  val get_transition_knowledge_rpcs_received : Counter.t

  val get_transition_chain_proof_rpcs_sent : Counter.t

  val get_transition_chain_proof_rpcs_received : Counter.t

  val get_node_status_rpcs_sent : Counter.t

  val get_node_status_rpcs_received : Counter.t

  val get_ancestry_rpcs_sent : Counter.t

  val get_ancestry_rpcs_received : Counter.t

  val ban_notify_rpcs_sent : Counter.t

  val ban_notify_rpcs_received : Counter.t

  val get_best_tip_rpcs_sent : Counter.t

  val get_best_tip_rpcs_received : Counter.t

  val get_epoch_ledger_rpcs_sent : Counter.t

  val get_epoch_ledger_rpcs_received : Counter.t

  module Ipc_latency_histogram : Histogram

  module Rpc_latency_histogram : Histogram

  module Rpc_size_histogram : Histogram

  val rpc_latency_ms : name:string -> Gauge.t

  val rpc_size_bytes : name:string -> Rpc_size_histogram.t

  val rpc_max_bytes : name:string -> Rpc_size_histogram.t

  val rpc_avg_bytes : name:string -> Rpc_size_histogram.t

  val rpc_latency_ms_summary : Rpc_latency_histogram.t

  val ipc_latency_ns_summary : Ipc_latency_histogram.t
end

module Snark_work : sig
  val useful_snark_work_received_time_sec : Gauge.t

  val completed_snark_work_received_gossip : Counter.t

  val completed_snark_work_received_rpc : Counter.t

  val snark_work_assigned_rpc : Counter.t

  val snark_work_timed_out_rpc : Counter.t

  val snark_pool_size : Gauge.t

  val pending_snark_work : Gauge.t

  module Snark_pool_serialization_ms_histogram : Histogram

  val snark_pool_serialization_ms : Snark_pool_serialization_ms_histogram.t

  module Snark_fee_histogram : Histogram

  val snark_fee : Snark_fee_histogram.t
end

module Scan_state_metrics : sig
  val scan_state_available_space : name:string -> Gauge.t

  val scan_state_base_snarks : name:string -> Gauge.t

  val scan_state_merge_snarks : name:string -> Gauge.t

  val snark_fee_per_block : Gauge.t

  val transaction_fees_per_block : Gauge.t

  val purchased_snark_work_per_block : Gauge.t

  val snark_work_required : Gauge.t
end

module Trust_system : sig
  val banned_peers : Gauge.t
end

module Consensus : sig
  val vrf_evaluations : Counter.t

  val staking_keypairs : Gauge.t

  val stake_delegators : Gauge.t
end

module Block_producer : sig
  val slots_won : Counter.t

  val blocks_produced : Counter.t
end

module Transition_frontier : sig
  val max_blocklength_observed : int ref

  val max_blocklength_observed_metrics : Gauge.t

  val update_max_blocklength_observed : int -> unit

  val max_unvalidated_blocklength_observed : int ref

  val max_unvalidated_blocklength_observed_metrics : Gauge.t

  val update_max_unvalidated_blocklength_observed : int -> unit

  val slot_fill_rate : Gauge.t

  val min_window_density : Gauge.t

  val active_breadcrumbs : Gauge.t

  val total_breadcrumbs : Counter.t

  val root_transitions : Counter.t

  val finalized_staged_txns : Counter.t

  module TPS_30min : sig
    val v : Gauge.t

    val update : float -> unit

    val clear : unit -> unit
  end

  val recently_finalized_staged_txns : Gauge.t

  val best_tip_user_txns : Gauge.t

  val best_tip_coinbase : Gauge.t

  val longest_fork : Gauge.t

  val empty_blocks_at_best_tip : Gauge.t

  val accepted_block_slot_time_sec : Gauge.t

  val best_tip_slot_time_sec : Gauge.t

  val best_tip_block_height : Gauge.t

  val root_snarked_ledger_accounts : Gauge.t

  val root_snarked_ledger_total_currency : Gauge.t
end

module Catchup : sig
  val download_time : Gauge.t

  val initial_validation_time : Gauge.t

  val verification_time : Gauge.t

  val build_breadcrumb_time : Gauge.t

  val initial_catchup_time : Gauge.t
end

module Transition_frontier_controller : sig
  val subsystem : string

  val transitions_being_processed : Gauge.t

  val transitions_in_catchup_scheduler : Gauge.t

  val catchup_time_ms : Gauge.t

  val transitions_downloaded_from_catchup : Gauge.t

  val breadcrumbs_built_by_processor : Counter.t

  val breadcrumbs_built_by_builder : Counter.t
end

module Block_latency : sig
  module Upload_to_gcloud : sig
    val upload_to_gcloud_blocks : Gauge.t
  end

  val block_window_duration : int

  module Gossip_slots : sig
    val v : Gauge.t

    val update : float -> unit

    val clear : unit -> unit
  end

  module Gossip_time : sig
    val v : Gauge.t

    val update : Core.Time.Span.t -> unit

    val clear : unit -> unit
  end

  module Inclusion_time : sig
    val v : Gauge.t

    val update : Core.Time.Span.t -> unit

    val clear : unit -> unit
  end
end

module Rejected_blocks : sig
  val worse_than_root : Counter.t

  val no_common_ancestor : Counter.t

  val invalid_proof : Counter.t

  val received_late : Counter.t

  val received_early : Counter.t
end

module Object_lifetime_statistics : sig
  val subsystem : string

  val allocated_count : name:string -> Counter.t

  val collected_count : name:string -> Counter.t

  val live_count : name:string -> Gauge.t

  val lifetime_quartile_ms :
    name:string -> quartile:[< `Q1 | `Q2 | `Q3 | `Q4 ] -> Gauge.t
end

val server :
     ?forward_uri:Uri.t
  -> port:int
  -> logger:Logger.t
  -> unit
  -> (Async.Socket.Address.Inet.t, int) Cohttp_async.Server.t Async.Deferred.t

module Archive : sig
  type t

  val subsystem : string

  val find_or_add :
    t -> name:string -> help:string -> subsystem:string -> Gauge.t

  val unparented_blocks : t -> Gauge.t

  val max_block_height : t -> Gauge.t

  val missing_blocks : t -> Gauge.t

  val create_archive_server :
       ?forward_uri:Uri.t
    -> port:int
    -> logger:Logger.t
    -> unit
    -> t Async.Deferred.t
end

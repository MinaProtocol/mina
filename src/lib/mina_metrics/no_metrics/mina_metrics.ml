open Core_kernel
open Async_kernel

let time_offset_sec = 1609459200.

module Counter = struct
  type t = unit

  let inc_one : t -> unit = fun _ -> ()

  let inc : t -> float -> unit = fun _ _ -> ()

  let value : t -> float =
   fun _ -> failwith "no_metrics doesn't store any value"
end

module Gauge = struct
  type t = unit

  let inc_one : t -> unit = fun _ -> ()

  let inc : t -> float -> unit = fun _ _ -> ()

  let dec_one : t -> unit = fun _ -> ()

  let dec : t -> float -> unit = fun _ _ -> ()

  let set : t -> float -> unit = fun _ _ -> ()

  let value : t -> float =
   fun _ -> failwith "no_metrics doesn't store any value"
end

module type Histogram = sig
  type t

  val observe : t -> float -> unit

  val buckets : t -> int list
end

module Histogram = struct
  type t = unit

  let observe : t -> float -> unit = fun _ _ -> ()

  let buckets () = []
end

module Runtime = struct
  let gc_stat_interval_mins : float ref = ref 15.

  module Long_async_histogram = Histogram

  let long_async_cycle : Long_async_histogram.t = ()

  module Long_job_histogram = Histogram

  let long_async_job : Long_job_histogram.t = ()
end

module Cryptography = struct
  let blockchain_proving_time_ms : Gauge.t = ()

  let total_pedersen_hashes_computed : Counter.t = ()

  module Snark_work_histogram = Histogram

  let snark_work_merge_time_sec : Snark_work_histogram.t = ()

  let snark_work_base_time_sec : Snark_work_histogram.t = ()

  let transaction_length : Gauge.t = ()

  let proof_zkapp_command : Gauge.t = ()
end

module Bootstrap = struct
  let bootstrap_time_ms : Gauge.t = ()

  let staking_epoch_ledger_sync_ms : Counter.t = ()

  let next_epoch_ledger_sync_ms : Counter.t = ()

  let root_snarked_ledger_sync_ms : Counter.t = ()

  let num_of_root_snarked_ledger_retargeted : Gauge.t = ()
end

module Transaction_pool = struct
  let useful_transactions_received_time_sec : Gauge.t = ()

  let pool_size : Gauge.t = ()

  let transactions_added_to_pool : Counter.t = ()

  let zkapp_command_transaction_size : Gauge.t = ()

  let zkapp_command_count : Gauge.t = ()
end

module Network = struct
  let peers : Gauge.t = ()

  let all_peers : Gauge.t = ()

  let validations_timed_out : Counter.t = ()

  let gossip_messages_failed_to_decode : Counter.t = ()

  let gossip_messages_received : Counter.t = ()

  module Block = struct
    let validations_timed_out : Counter.t = ()

    let rejected : Counter.t = ()

    let ignored : Counter.t = ()

    let received : Counter.t = ()

    module Validation_time = struct
      let update : Time.Span.t -> unit = Fn.ignore
    end

    module Processing_time = struct
      let update : Time.Span.t -> unit = Fn.ignore
    end

    module Rejection_time = struct
      let update : Time.Span.t -> unit = Fn.ignore
    end
  end

  module Snark_work = struct
    let validations_timed_out : Counter.t = ()

    let rejected : Counter.t = ()

    let ignored : Counter.t = ()

    let received : Counter.t = ()

    module Validation_time = struct
      let update : Time.Span.t -> unit = Fn.ignore
    end

    module Processing_time = struct
      let update : Time.Span.t -> unit = Fn.ignore
    end

    module Rejection_time = struct
      let update : Time.Span.t -> unit = Fn.ignore
    end
  end

  module Transaction = struct
    let validations_timed_out : Counter.t = ()

    let rejected : Counter.t = ()

    let ignored : Counter.t = ()

    let received : Counter.t = ()

    module Validation_time = struct
      let update : Time.Span.t -> unit = Fn.ignore
    end

    module Processing_time = struct
      let update : Time.Span.t -> unit = Fn.ignore
    end

    module Rejection_time = struct
      let update : Time.Span.t -> unit = Fn.ignore
    end
  end

  let rpc_requests_received : Counter.t = ()

  let rpc_requests_sent : Counter.t = ()

  let get_some_initial_peers_rpcs_sent : Counter.t * Gauge.t = ((), ())

  let get_some_initial_peers_rpcs_received : Counter.t * Gauge.t = ((), ())

  let get_some_initial_peers_rpc_requests_failed : Counter.t = ()

  let get_some_initial_peers_rpc_responses_failed : Counter.t = ()

  let get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_sent :
      Counter.t * Gauge.t =
    ((), ())

  let get_staged_ledger_aux_and_pending_coinbases_at_hash_rpcs_received :
      Counter.t * Gauge.t =
    ((), ())

  let get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc_requests_failed :
      Counter.t =
    ()

  let get_staged_ledger_aux_and_pending_coinbases_at_hash_rpc_responses_failed :
      Counter.t =
    ()

  let answer_sync_ledger_query_rpcs_sent : Counter.t * Gauge.t = ((), ())

  let answer_sync_ledger_query_rpcs_received : Counter.t * Gauge.t = ((), ())

  let answer_sync_ledger_query_rpc_requests_failed : Counter.t = ()

  let answer_sync_ledger_query_rpc_responses_failed : Counter.t = ()

  let get_transition_chain_rpcs_sent : Counter.t * Gauge.t = ((), ())

  let get_transition_chain_rpcs_received : Counter.t * Gauge.t = ((), ())

  let get_transition_chain_rpc_requests_failed : Counter.t = ()

  let get_transition_chain_rpc_responses_failed : Counter.t = ()

  let get_transition_knowledge_rpcs_sent : Counter.t * Gauge.t = ((), ())

  let get_transition_knowledge_rpcs_received : Counter.t * Gauge.t = ((), ())

  let get_transition_knowledge_rpc_requests_failed : Counter.t = ()

  let get_transition_knowledge_rpc_responses_failed : Counter.t = ()

  let get_transition_chain_proof_rpcs_sent : Counter.t * Gauge.t = ((), ())

  let get_transition_chain_proof_rpcs_received : Counter.t * Gauge.t = ((), ())

  let get_transition_chain_proof_rpc_requests_failed : Counter.t = ()

  let get_transition_chain_proof_rpc_responses_failed : Counter.t = ()

  let get_node_status_rpcs_sent : Counter.t * Gauge.t = ((), ())

  let get_node_status_rpcs_received : Counter.t * Gauge.t = ((), ())

  let get_node_status_rpc_requests_failed : Counter.t = ()

  let get_node_status_rpc_responses_failed : Counter.t = ()

  let get_ancestry_rpcs_sent : Counter.t * Gauge.t = ((), ())

  let get_ancestry_rpcs_received : Counter.t * Gauge.t = ((), ())

  let get_ancestry_rpc_requests_failed : Counter.t = ()

  let get_ancestry_rpc_responses_failed : Counter.t = ()

  let ban_notify_rpcs_sent : Counter.t * Gauge.t = ((), ())

  let ban_notify_rpcs_received : Counter.t * Gauge.t = ((), ())

  let ban_notify_rpc_requests_failed : Counter.t = ()

  let ban_notify_rpc_responses_failed : Counter.t = ()

  let get_best_tip_rpcs_sent : Counter.t * Gauge.t = ((), ())

  let get_best_tip_rpcs_received : Counter.t * Gauge.t = ((), ())

  let get_best_tip_rpc_requests_failed : Counter.t = ()

  let get_best_tip_rpc_responses_failed : Counter.t = ()

  let get_epoch_ledger_rpcs_sent : Counter.t * Gauge.t = ((), ())

  let get_epoch_ledger_rpcs_received : Counter.t * Gauge.t = ((), ())

  let new_state_received : Gauge.t = ()

  let new_state_broadcasted : Gauge.t = ()

  let snark_pool_diff_received : Gauge.t = ()

  let snark_pool_diff_broadcasted : Gauge.t = ()

  let transaction_pool_diff_received : Gauge.t = ()

  let transaction_pool_diff_broadcasted : Gauge.t = ()

  let get_epoch_ledger_rpc_requests_failed : Counter.t = ()

  let get_epoch_ledger_rpc_responses_failed : Counter.t = ()

  let rpc_connections_failed : Counter.t = ()

  module Ipc_latency_histogram = Histogram
  module Rpc_latency_histogram = Histogram
  module Rpc_size_histogram = Histogram

  let rpc_latency_ms : name:string -> Gauge.t = fun ~name:_ -> ()

  let rpc_size_bytes : name:string -> Rpc_size_histogram.t = fun ~name:_ -> ()

  let rpc_max_bytes : name:string -> Rpc_size_histogram.t = fun ~name:_ -> ()

  let rpc_avg_bytes : name:string -> Rpc_size_histogram.t = fun ~name:_ -> ()

  let rpc_latency_ms_summary : Rpc_latency_histogram.t = ()

  let ipc_latency_ns_summary : Ipc_latency_histogram.t = ()

  let ipc_logs_received_total : Counter.t = ()
end

module Pipe = struct
  module Drop_on_overflow = struct
    let bootstrap_sync_ledger : Counter.t = ()

    let verified_network_pool_diffs : Counter.t = ()

    let transition_frontier_valid_transitions : Counter.t = ()

    let transition_frontier_primary_transitions : Counter.t = ()

    let router_transition_frontier_controller : Counter.t = ()

    let router_bootstrap_controller : Counter.t = ()

    let router_verified_transitions : Counter.t = ()

    let router_transitions : Counter.t = ()

    let router_valid_transitions : Counter.t = ()
  end
end

module Snark_work = struct
  let useful_snark_work_received_time_sec : Gauge.t = ()

  let completed_snark_work_received_rpc : Counter.t = ()

  let snark_work_assigned_rpc : Counter.t = ()

  let snark_work_timed_out_rpc : Counter.t = ()

  let snark_work_failed_rpc : Counter.t = ()

  let snark_pool_size : Gauge.t = ()

  let pending_snark_work : Gauge.t = ()

  module Snark_pool_serialization_ms_histogram = Histogram

  let snark_pool_serialization_ms : Snark_pool_serialization_ms_histogram.t = ()

  module Snark_fee_histogram = Histogram

  let snark_fee : Snark_fee_histogram.t = ()
end

module Scan_state_metrics = struct
  let scan_state_available_space : name:string -> Gauge.t = fun ~name:_ -> ()

  let scan_state_base_snarks : name:string -> Gauge.t = fun ~name:_ -> ()

  let scan_state_merge_snarks : name:string -> Gauge.t = fun ~name:_ -> ()

  let snark_fee_per_block : Gauge.t = ()

  let transaction_fees_per_block : Gauge.t = ()

  let purchased_snark_work_per_block : Gauge.t = ()

  let snark_work_required : Gauge.t = ()
end

module Trust_system = struct
  let banned_peers : Gauge.t = ()
end

module Consensus = struct
  let vrf_evaluations : Counter.t = ()

  let staking_keypairs : Gauge.t = ()

  let stake_delegators : Gauge.t = ()
end

module Block_producer = struct
  let slots_won : Counter.t = ()

  let blocks_produced : Counter.t = ()

  module Block_production_delay_histogram = Histogram

  let block_production_delay : Block_production_delay_histogram.t = ()
end

module Transition_frontier = struct
  let max_blocklength_observed : int ref = ref 0

  let max_blocklength_observed_metrics : Gauge.t = ()

  let update_max_blocklength_observed : int -> unit = fun _ -> ()

  let max_unvalidated_blocklength_observed : int ref = ref 0

  let max_unvalidated_blocklength_observed_metrics : Gauge.t = ()

  let update_max_unvalidated_blocklength_observed : int -> unit = fun _ -> ()

  let slot_fill_rate : Gauge.t = ()

  let min_window_density : Gauge.t = ()

  let active_breadcrumbs : Gauge.t = ()

  let total_breadcrumbs : Counter.t = ()

  let root_transitions : Counter.t = ()

  let finalized_staged_txns : Counter.t = ()

  module TPS_30min = struct
    let v : Gauge.t = ()

    let update : float -> unit = fun _ -> ()

    let clear : unit -> unit = fun _ -> ()
  end

  let recently_finalized_staged_txns : Gauge.t = ()

  let best_tip_user_txns : Gauge.t = ()

  let best_tip_zkapp_txns : Gauge.t = ()

  let best_tip_coinbase : Gauge.t = ()

  let longest_fork : Gauge.t = ()

  let empty_blocks_at_best_tip : Gauge.t = ()

  let accepted_block_slot_time_sec : Gauge.t = ()

  let best_tip_slot_time_sec : Gauge.t = ()

  let best_tip_block_height : Gauge.t = ()

  let root_snarked_ledger_accounts : Counter.t = ()

  let root_snarked_ledger_total_currency : Gauge.t = ()
end

module Catchup = struct
  let download_time : Gauge.t = ()

  let initial_validation_time : Gauge.t = ()

  let verification_time : Gauge.t = ()

  let build_breadcrumb_time : Gauge.t = ()

  let initial_catchup_time : Gauge.t = ()
end

module Transition_frontier_controller = struct
  let transitions_being_processed : Gauge.t = ()

  let transitions_in_catchup_scheduler : Gauge.t = ()

  let catchup_time_ms : Gauge.t = ()

  let transitions_downloaded_from_catchup : Gauge.t = ()

  let breadcrumbs_built_by_processor : Counter.t = ()

  let breadcrumbs_built_by_builder : Counter.t = ()
end

module Block_latency = struct
  module Upload_to_gcloud = struct
    let upload_to_gcloud_blocks : Gauge.t = ()
  end

  module Gossip_slots = struct
    let v : Gauge.t = ()

    let update : float -> unit = fun _ -> ()

    let clear : unit -> unit = fun _ -> ()
  end

  module Gossip_time = struct
    let v : Gauge.t = ()

    let update : Time.Span.t -> unit = fun _ -> ()

    let clear : unit -> unit = fun _ -> ()
  end

  module Inclusion_time = struct
    let v : Gauge.t = ()

    let update : Time.Span.t -> unit = fun _ -> ()

    let clear : unit -> unit = fun _ -> ()
  end

  module Validation_acceptance_time = struct
    let v : Gauge.t = ()

    let update : Time.Span.t -> unit = fun _ -> ()

    let clear : unit -> unit = fun _ -> ()
  end
end

module Rejected_blocks = struct
  let worse_than_root : Counter.t = ()

  let no_common_ancestor : Counter.t = ()

  let invalid_proof : Counter.t = ()

  let received_late : Counter.t = ()

  let received_early : Counter.t = ()
end

module Object_lifetime_statistics = struct
  let allocated_count : name:string -> Counter.t = fun ~name:_ -> ()

  let collected_count : name:string -> Counter.t = fun ~name:_ -> ()

  let live_count : name:string -> Gauge.t = fun ~name:_ -> ()

  let lifetime_quartile_ms :
      name:string -> quartile:[< `Q1 | `Q2 | `Q3 | `Q4 ] -> Gauge.t =
   fun ~name:_ ~quartile:_ -> ()
end

type t

let server :
    ?forward_uri:Uri.t -> port:int -> logger:Logger.t -> unit -> t Deferred.t =
 fun ?forward_uri:_ ~port:_ ~logger:_ _ ->
  failwith "No metrics server available"

module Archive = struct
  type t

  let unparented_blocks : t -> Gauge.t = fun _ -> ()

  let max_block_height : t -> Gauge.t = fun _ -> ()

  let missing_blocks : t -> Gauge.t = fun _ -> ()

  let create_archive_server :
      ?forward_uri:Uri.t -> port:int -> logger:Logger.t -> unit -> t Deferred.t
      =
   fun ?forward_uri:_ ~port:_ ~logger:_ _ ->
    failwith "No metrics server available"
end

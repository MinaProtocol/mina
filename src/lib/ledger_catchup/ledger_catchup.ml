module Catchup_jobs = Catchup_jobs
module Best_tip_lru = Best_tip_lru

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val proof_cache_db : Proof_cache_tag.cache_db

  val signature_kind : Mina_signature_kind.t
end

let create_job_handler ~context:(module Context : CONTEXT) ~trust_system
    ~verifier ~network ~frontier ~catchup_breadcrumbs_writer ~block_registry
    ~in_flight ~schedule =
  Super_catchup.create_job_handler
    ~context:(module Context)
    ~trust_system ~verifier ~network ~frontier ~catchup_breadcrumbs_writer
    ~block_registry ~in_flight ~schedule
    ~build_func:
      (Transition_frontier.Breadcrumb.build
         ~get_completed_work:(Core_kernel.Fn.const None) )

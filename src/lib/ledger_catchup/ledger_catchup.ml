module Catchup_jobs = Catchup_jobs
module Best_tip_lru = Best_tip_lru

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val verifier : Verifier.t

  val trust_system : Trust_system.t

  val network : Mina_networking.t
end

let run ~context:(module Context : CONTEXT) ~frontier ~catchup_job_reader
    ~catchup_breadcrumbs_writer ~unprocessed_transition_cache : unit =
  match Transition_frontier.catchup_tree frontier with
  | Hash _ ->
      Normal_catchup.run
        ~context:(module Context)
        ~frontier ~catchup_job_reader ~catchup_breadcrumbs_writer
        ~unprocessed_transition_cache
  | Full _ ->
      Super_catchup.run
        ~context:(module Context)
        ~frontier ~catchup_job_reader ~catchup_breadcrumbs_writer
        ~unprocessed_transition_cache

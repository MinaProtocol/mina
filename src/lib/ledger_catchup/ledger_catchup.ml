module Catchup_jobs = Catchup_jobs
module Best_tip_lru = Best_tip_lru

let run ~logger ~precomputed_values ~trust_system ~verifier ~network ~frontier
    ~catchup_job_reader ~catchup_breadcrumbs_writer
    ~unprocessed_transition_cache : unit =
  match Transition_frontier.catchup_tree frontier with
  | Hash _ ->
      Normal_catchup.run ~logger ~precomputed_values ~trust_system ~verifier
        ~network ~frontier ~catchup_job_reader ~catchup_breadcrumbs_writer
        ~unprocessed_transition_cache
  | Full _ ->
      Super_catchup.run ~logger ~precomputed_values ~trust_system ~verifier
        ~network ~frontier ~catchup_job_reader ~catchup_breadcrumbs_writer
        ~unprocessed_transition_cache

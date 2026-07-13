# Work Selector

The work selector maintains an internal state of available SNARK work specs. This state is updated reactively via broadcast pipe subscriptions: a `frontier_broadcast_pipe` provides the current transition frontier, and within it a `best_tip_pipe` signals when the best tip changes. On each best tip update, the work selector queries `all_work_pairs` from the best tip staged ledger to refresh its available jobs.

When new jobs arrive, `available_jobs` is replaced with the new set. The `jobs_scheduled` set is intersected with the new job keys, removing any scheduled entries that are no longer relevant while retaining those that still appear in the updated job list.

When queried, the work selector uses a configurable selection method (random, sequential, or random-offset) to sample work from its internal state, filtering out jobs that have already been scheduled and jobs for which the snark pool already has a cheaper proof.

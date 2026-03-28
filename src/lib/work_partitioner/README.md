#### Context
A work partitioner is the component sitting between the work selector and the RPC endpoint managed in Mina_run & Mina_lib. 

As a recap, integrity of transactions on the mina blockchain is ensured by transaction SNARKs. When work selector is queried, it would return a list of work specs, each correspond to one or two transactions (this is due to the structure of parallel scan), indicating the daemon needs transaction SNARK proofs for those transactions to move forward. During Mesa HF, we aim to refactor SNARK worker so it only generates one proof a time, hence more parallelism could be utilized.

However, there's a gap in abstraction level, in work selector, each transaction could correspond to multiple proofs, if the transactoin is a zkApp command. Hence, we created this component which is in charge of:
- Partition work specs from work selector to segment proofs and sub-zkApp merge specs;
- Rescheduling (this used to be done in work selector, now moving to work partitioner in finer grain)
- Combining results from SNARK workers and submit them back to work selector

#### Data structures
There're several data structures defined in a work partitioner. 

A pairing pool tracks completed work specs that should be paired up before sending back to work selector (in correspondence with the pair originally provided by the work selector). 

A zkApp command pool contains "pending zkApp command"s. A pending zkApp command contains the spec, unscheduled specs, and some partially submitted proofs. It's in charge of generating a stream of sub-zkApp level merge or segment proof specs. When a zkApp command is received, it would be converted to a "pending zkApp command" and thrown into zkApp command pool, and on completion of the final merge of a "pending zkApp command", it would be thrown back to pairing pool if needed, or submitted directly to work selector if it doesn't need pairing up.

We have 2 distinct pools, `zkapp_jobs_sent_by_partitioner` and `single_jobs_sent_by_partitioner`, as names suggest, they track any jobs distributed by the work partitioner, and reschedule the them on timeout so if a SNARK worker is unresponsive, the coordinator won't be stuck. To clarify, a single job is a request for either a merge of proofs in parallel scan or a proof for a non-zkApp transaction.

Finally, there's an temporary slot that is in charge of lazily converting work specs received from work selector to data stored inside work partitioner. Precisely, when a pair of work specs is received, one of the specs is stored in the temporary slot, while the other is submitted immediately to the work partitioner. Part from temporary slot will be returned on next call to the work partitioner, and the temporary slot will be emptied.

#### TODOs
In future refactoring, we could consider merging work selector and partitioner into the same component, but we'd need to refactor selector first.

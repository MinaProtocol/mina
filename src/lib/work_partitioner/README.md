#### Context
A work partitioner is the component sitting between the work selector and the RPC endpoint managed in Mina_run & Mina_lib. 

As a recap, integrity of transactions on the mina blockchain is ensured by transaction SNARKs. When work selector is queries, it would return a list of work specs, each correspond to one or two transactions(this is due to the structure of parallel scan). During this HF, we aim to refactor SNARK worker so it only generate one proof a time, hence more parallelism could be utilized.

However, there's a gap in abstraction level, in work selector, each transaction could correspond to multiple proofs, if the transactoin is a zkApp command. Hence, we have this component which is in charge of:
- Partition work specs from work selector to segment proof/ sub-zkApp merge specs;
- Rescheduling(this used to be done in work selector, now moving to work partitioner in finer grain)
- Combining results from SNARK workers and submit them back to work selector

#### Data structures
There's several data structure defined in a work partitioner. 

A pairing pool tracks completed transactions that should be paired up before sending back to work selector. In a zkApp command pool, each element is a "pending zkApp command". 

A pending zkApp command contains the spec, unscheduled infos, and some partially submitted proofs, it's in charge of generating a sub-zkApp level merge or segment proof spec. When a zkApp command is received, it would be converted to a "pending zkApp command" and thrown into zkApp command pool, and on completion of the final merge of a "pending zkApp command", it would be thrown back to pairing pool if needed, or submitted directly to work selector if it doesn't need pairing up.

We have 2 distinct pools, zkapp_jobs_sent_by_partitioner and single_jobs_sent_by_partitioner, as the name suggest, they should track any jobs distributed by the work partitioner, and reschedule the them on timeout so if a SNARK worker dead the coordinator is unaffected. 

Lastly, there's an temporary slot that is in charge of lazily convert works received from work selector to datas stored inside work parititioner. When a pair of transactions are received, one of it is stored in this slot so to defer the parititoning in case it's a zkApp transaction, until needed.

#### TODOs
In future refactor, we could consider merging work selector and partitioner into the same component, but we need to refactor selector first.

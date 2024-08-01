# Modeling - Metrics

Currently this python script queries Prometheus and plots some metrics.
The ultimate goal is to build a model which can be used to make predictions about safely lowering slot times.

To run it use `python main.py` either with the python provided from `shell.nix`
or you can look at shell.nix for which packages are needed and pip install them.
You will also need an oath2 token in `auth.token`.
You can get this by running a query in your browser with the network tab open
and looking at the cookies for the http request.

# Core block production metrics

When a block is successfully produced the first metric to increase is `Coda_Block_producer_blocks_produced`.
This only reflects the block being constructed not necessarily accepted.

If that block is broadcast successfully `Coda_Network_new_state_broadcasted` will increment next,
this is usually simultaneous to the resolution of our metrics.

Finally `Coda_Block_producer_slots_won` increases, in the case that the block is not constructed
this is also the first metric to increase.

These metrics are used determine when blocks are produced and when block production fails.

# Other metrics

The metric `Mina_Daemon_time_spent_in_thread_produce_blocks_ms` is broken seemingly because the thread never exits.

The metric `Coda_Block_producer_block_production_delay_sum` tracks how long it takes to construct each block.

Hopefully one of these metrics gives an accurate indication of the network latency
- `Coda_Network_ipc_latency_ns_summary_sum`
- `Coda_Network_answer_sync_ledger_query_latency`

These metrics may also be usefull:
- Coda_Block_latency_gossip_slots
- Coda_Block_latency_gossip_time
- Coda_Block_producer_block_production_delay_sum
- Coda_Cryptography_zkapp_transaction_length
- Coda_Cryptography_zkapp_transaction_size
- Coda_Network_answer_sync_ledger_query_latency
- Coda_Network_new_state_broadcasted
- Coda_Network_rpc_latency_ms_summary
- Coda_Rejected_blocks_received_late
- Coda_Runtime_process_cpu_seconds_total
- Coda_Runtime_process_uptime_ms_total
- Coda_Scan_state_purchased_snark_work_per_block
- Coda_Snark_work_snark_pool_size
- Coda_Snark_work_useful_snark_work_received_time_sec
- Coda_Transaction_pool_size
- Coda_Transaction_pool_zkapp_proof_updates
- Coda_Transaction_pool_zkapp_transactions_added_to_pool
- Coda_Transition_frontier_best_tip_user_txns
- Coda_Transition_frontier_longest_fork
- Coda_Transition_frontier_longest_fork
- Mina_Daemon_time_spent_in_thread_batching_transaction_verification_ms
- Mina_Daemon_time_spent_in_thread_dispatch_blockchain_snark_verification_ms
- Mina_Daemon_time_spent_in_thread_generate_consensus_transition_ms
- Mina_Daemon_time_spent_in_thread_generate_internal_transition_ms
- Mina_Daemon_time_spent_in_thread_generate_snark_transition_ms
- Mina_Daemon_time_spent_in_thread_generate_staged_ledger_diff_ms
- Mina_Daemon_time_spent_in_thread_produce_blocks_ms
- alertmanager_nflog_gossip_messages_propagated_total
- container_memory_max_usage_bytes
- container_memory_usage_bytes
- kube_pod_container_status_restarts_total
- kubelet_node_startup_duration_seconds
- kubelet_node_startup_duration_seconds
- node_forks_total
- prometheus_tsdb_blocks_loaded

# Construction failures
Looking at the data from individual nodes it seems that nodes ocaionally enter a state where
they begins failing to produce blocks much more frequently, going from usually <1% to between 60-99% failures.
I'm not sure why this happens.

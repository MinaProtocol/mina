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


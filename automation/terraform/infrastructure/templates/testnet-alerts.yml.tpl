# $: rule_filter - filter for subset of testnets to include in rule alert search space
# $: alerting_timeframe - range of time to inspect for alert rule violations

namespace: testnet-alerts
groups:
- name: Critical Alerts
  rules:
  - alert: BlockProductionStopped
    expr: avg by (testnet) (increase(Coda_Transition_frontier_max_blocklength_observed ${rule_filter} [${alerting_timeframe}])) < 1
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: critical
    annotations:
      summary: "{{ $labels.testnet }} block production is critically low"
      description: "Zero blocks have been produced on network {{ $labels.testnet }}."

  - alert: LowPeerCount
    expr: avg by (testnet) (max_over_time(Coda_Network_peers ${rule_filter} [${alerting_timeframe}])) < 1
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: critical
    annotations:
      summary: "{{ $labels.testnet }} avg. peer count is critically low"
      description: "Critically low peer count on network {{ $labels.testnet }}."

  - alert: LowMinWindowDensity
    expr: max by (testnet) (Coda_Transition_frontier_min_window_density ${rule_filter}) < 0.75 * 0.75 * 77
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: critical
    annotations:
      summary: "{{ $labels.testnet }} min density is low"
      description: "Critically low min density on network {{ $labels.testnet }}."

  - alert: LowFillRate
    expr: max by (testnet) (Coda_Transition_frontier_slot_fill_rate ${rule_filter}) < 0.75 * 0.75
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: critical
    annotations:
      summary: "{{ $labels.testnet }} avg. peer count is critically low"
      description: "Lower fill rate than expected on network {{ $labels.testnet }}."

  - alert: NoTransactionsInSeveralBlocks
    expr: max by (testnet) (Coda_Transition_frontier_empty_blocks_at_best_tip ${rule_filter}) >= 5
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: critical
    annotations:
      summary: "{{ $labels.testnet }} has >= 5 blocks without transactions at the tip"
      description: "At least 5 blocks without transactions on tip of network {{ $labels.testnet }}."

  - alert: NoCoinbaseInBlocks
    expr: min by (testnet) (min_over_time(Coda_Transition_frontier_best_tip_coinbase ${rule_filter} [10m])) < 1
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: critical
    annotations:
      summary: "{{ $labels.testnet }} has blocks without coinbases"
      description: "Blocks without coinbases on tip of network {{ $labels.testnet }}."

  - alert: LongFork
    expr: max by (testnet) (Coda_Transition_frontier_longest_fork ${rule_filter}) >= 16
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: critical
    annotations:
      summary: "{{ $labels.testnet }} has a fork of length at least 16"
      description: "Fork of length at least 16 on network {{ $labels.testnet }}."

  - alert: OldBestTip
    expr: min by (testnet) ((time() - 1609459200) - Coda_Transition_frontier_best_tip_slot_time_sec ${rule_filter}) >= 15 * 180
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: critical
    annotations:
      summary: "{{ $labels.testnet }}: all nodes have best tips older than 15 slots"
      description: "All nodes have best tips older than 15 slots (45 minutes) on network {{ $labels.testnet }}."

  - alert: NoNewSnarks
    expr: min by (testnet) ((time() - 1609459200) - Coda_Snark_work_useful_snark_work_received_time_sec ${rule_filter}) >= 2 * 180
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: critical
    annotations:
      summary: "{{ $labels.testnet }}: no new SNARK work seen for 2 slots."
      description: "No node has received SNARK work in the last 2 slots (6 minutes) on network {{ $labels.testnet }}."

  - alert: NoNewTransactions
    expr: min by (testnet) ((time() - 1609459200) - Coda_Transaction_pool_useful_transactions_received_time_sec ${rule_filter}) >= 60 * 30
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: critical
    annotations:
      summary: "{{ $labels.testnet }}: no new transactions seen for 30 minutes."
      description: "No node has received transactions in their transaction pool in the last 30 minutes on network {{ $labels.testnet }}."

- name: Warnings
  rules:
  - alert: HighBlockGossipLatency
    expr: avg by (testnet) (max_over_time(Coda_Block_latency_gossip_time ${rule_filter} [${alerting_timeframe}])) > 200
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: warning
    annotations:
      summary: "{{ $labels.testnet }} block gossip latency is high"
      description: "High block gossip latency (ms) within {{ $labels.testnet }} network."

  - alert: SomewhatOldBestTip
    expr: min by (testnet) ((time() - 1609459200) - Coda_Transition_frontier_best_tip_slot_time_sec ${rule_filter}) >= 8 * 180
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: warning
    annotations:
      summary: "{{ $labels.testnet }}: all nodes have best tips older than 8 slots"
      description: "All nodes have best tips older than 8 slots (24 minutes) on network {{ $labels.testnet }}."

  - alert: MediumFork
    expr: max by (testnet) (Coda_Transition_frontier_longest_fork ${rule_filter}) >= 8
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: warning
    annotations:
      summary: "{{ $labels.testnet }} has a fork of length at least 8"
      description: "Fork of length at least 8 on network {{ $labels.testnet }}."

  - alert: NoTransactionsInAtLeastOneBlock
    expr: max by (testnet) (max_over_time(Coda_Transition_frontier_empty_blocks_at_best_tip ${rule_filter} [${alerting_timeframe}])) > 0
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: warning
    annotations:
      summary: "{{ $labels.testnet }} has at least 1 block without transactions at the tip"
      description: "At least 5 blocks without transactions on tip of network {{ $labels.testnet }} within ${alerting_timeframe}."


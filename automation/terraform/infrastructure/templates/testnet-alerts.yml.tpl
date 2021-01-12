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
      description: "Zero blocks have been produced on testnet {{ $labels.testnet }}."

  - alert: LowPeerCount
    expr: avg by (testnet) (max_over_time(Coda_Network_peers ${rule_filter} [${alerting_timeframe}])) < 1
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: critical
    annotations:
      summary: "{{ $labels.testnet }} avg. peer count is critically low"
      description: "Critically low peer count on testnet {{ $labels.testnet }}."

- name: Warnings
  rules:
  - alert: HighBlockGossipLatency
    expr: avg by (testnet) (max_over_time(Coda_Block_latency_gossip_time ${rule_filter} [${alerting_timeframe}])) > 200
    labels:
      testnet: "{{ $labels.testnet }}"
      severity: warning
    annotations:
      summary: "{{ $labels.testnet }} block gossip latency is high"
      description: "High block gossip latency (ms) within {{ $labels.testnet }} testnet."

# Proposal: Monitoring Starter Pack (Alerting Rules + Grafana Dashboard)

## Problem

The daemon exports ~60+ Prometheus metrics but there are no pre-built alerting rules, Grafana dashboards, or monitoring guides. Operators must reverse-engineer metric names from OCaml source code.

## Comparison

- **Ethereum**: Lighthouse ships Grafana dashboards. Prysm has a built-in web UI.
- **Cosmos**: Community maintains validator monitoring repos with alertmanager configs.
- **Solana**: `solana-watchtower` is a built-in alerting service.

## Proposed Deliverables

### 1. Prometheus Alerting Rules (`scripts/monitoring/mina-alerts.yml`)

```yaml
groups:
  - name: mina-node
    rules:
      - alert: MinaNodeNotSynced
        expr: mina_Sync_status != 1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Mina node is not synced"

      - alert: MinaLowPeerCount
        expr: mina_Network_peers < 3
        for: 2m
        labels:
          severity: warning

      - alert: MinaNoBlocksProduced
        expr: rate(mina_Block_producer_blocks_produced[1h]) == 0 AND mina_Block_producer_slots_won > 0
        for: 30m
        labels:
          severity: critical

      - alert: MinaHighMemoryUsage
        expr: mina_Process_memory_rss_bytes > 16e9
        for: 5m
        labels:
          severity: warning

      - alert: MinaArchiveMissingBlocks
        expr: mina_Archive_missing_blocks > 0
        for: 10m
        labels:
          severity: warning
```

### 2. Grafana Dashboard (`scripts/monitoring/grafana-mina-dashboard.json`)

Panels:
- Sync status (state timeline)
- Block height (time series)
- Peer count (gauge + graph)
- Block production rate (counter rate)
- SNARK pool size and pending work
- Transaction pool size
- Memory usage per subprocess
- Network message rates
- Bootstrap/catchup progress

### 3. Prometheus Metrics Catalog (`docs/prometheus-metrics.md`)

Document every metric: name, type (counter/gauge/histogram), labels, and description.

### 4. Monitoring Guide (`docs/monitoring-guide.md`)

- How to enable `--metrics-port`
- Prometheus scrape config
- Recommended alertmanager setup
- How to import the Grafana dashboard

## Effort Estimate

Medium --- 3-5 days to build and test dashboards against a real node.

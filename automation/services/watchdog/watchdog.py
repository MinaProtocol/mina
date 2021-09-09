# Example of running locally
# SEED_PEERS_URL=https://raw.githubusercontent.com/MinaProtocol/coda-automation/bug-bounty-net/terraform/testnets/testworld/peers.txt LOCAL_KUBERNETES=true KUBERNETES_NAMESPACE=watchdog-test METRICS_PORT=8000 python3 watchdog.py

from prometheus_client import start_http_server, Summary
import time
import os
import json
from prometheus_client import Counter
from prometheus_client import Gauge
import asyncio
import util

import metrics

# =================================================

def main():
  print('starting watchdog')

  port = int(os.environ['METRICS_PORT'])
  start_http_server(port)

  v1, namespace = util.get_kubernetes()

  cluster_crashes = Gauge('Coda_watchdog_cluster_crashes', 'Description of gauge')
  error_counter = Counter('Coda_watchdog_errors', 'Description of gauge')

  nodes_synced_near_best_tip = Gauge('Coda_watchdog_nodes_synced_near_best_tip', 'Description of gauge')
  nodes_synced = Gauge('Coda_watchdog_nodes_synced', 'Description of gauge')
  prover_errors = Counter('Coda_watchdog_prover_errors', 'Description of gauge')
  pods_with_no_new_logs = Gauge('Coda_watchdog_pods_with_no_new_logs', 'Number of nodes whose latest log is older than 10 minutes')

  recent_google_bucket_blocks = Gauge('Coda_watchdog_recent_google_bucket_blocks', 'Description of gauge')
  seeds_reachable = Gauge('Coda_watchdog_seeds_reachable', 'Description of gauge')

  # ========================================================================

  fns = [
    ( lambda: metrics.collect_cluster_crashes(v1, namespace, cluster_crashes), 30*60 ),
    ( lambda: metrics.collect_node_status_metrics(v1, namespace, nodes_synced_near_best_tip, nodes_synced, prover_errors), 60*60 ),
    ( lambda: metrics.check_seed_list_up(v1, namespace, seeds_reachable), 60*60 ),
    ( lambda: metrics.pods_with_no_new_logs(v1, namespace, pods_with_no_new_logs), 60*10 ),
  ]

  if os.environ.get('CHECK_GCLOUD_STORAGE_BUCKET') is not None:
    fns += [ ( lambda: metrics.check_google_storage_bucket(v1, namespace, recent_google_bucket_blocks), 30*60 ) ]

  for fn, time_between in fns:
    asyncio.ensure_future(util.run_periodically(fn, time_between, error_counter))

  loop = asyncio.get_event_loop()
  loop.run_forever()

main()

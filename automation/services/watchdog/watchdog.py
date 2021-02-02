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
  port = int(os.environ['METRICS_PORT'])
  start_http_server(port)

  v1, namespace = util.get_kubernetes()

  cluster_crashes = Gauge('Coda_watchdog_cluster_crashes', 'Description of gauge')
  error_counter = Counter('Coda_watchdog_errors', 'Description of gauge')

  # ========================================================================

  fns = [
    ( lambda: metrics.collect_cluster_crashes(v1, namespace, cluster_crashes), 30*60 ),
  ]

  # ========================================================================

  for fn, time_between in fns:
    asyncio.run(util.run_periodically(fn, time_between, error_counter))

main()


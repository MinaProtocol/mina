from prometheus_client import start_http_server, Summary
import time
import os

if __name__ == '__main__':
  port = int(os.environ['METRICS_PORT'])
  start_http_server(port)

  from prometheus_client import Counter
  c = Counter('Coda_watchdog_increment_tests', 'Testing incrementing')

  from prometheus_client import Gauge
  g = Gauge('Coda_watchdog_gauge_test', 'Description of gauge')

  while True:
    time.sleep(1)
    c.inc()
    g.inc()
    g.inc()

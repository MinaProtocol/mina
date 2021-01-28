from prometheus_client import start_http_server, Summary
import time
import os
import zmq
import json
from prometheus_client import Counter
from prometheus_client import Gauge

# =================================================

def make_metrics():
  cluster_crashes = Gauge('Coda_watchdog_cluster_crashes', 'Description of gauge')
  cluster_crashes.set(0)

  metric_table = {
    "cluster_crashes": cluster_crashes
  }

  return metric_table

# =================================================

def main():
  port = int(os.environ['METRICS_PORT'])
  start_http_server(port)

  metric_table = make_metrics()

  context = zmq.Context()
  socket = context.socket(zmq.REP)
  socket.bind('tcp://0.0.0.0:5555')

  while True:
    msg = socket.recv()
    try:
      obj = json.loads(msg)
      if obj['type'] == 'gauge':
        gauge = metric_table[obj['metric']]
        gauge.set(obj['value'])
      else:
        raise Exception('unknown message type')
    except Exception as e:
      print(e)
      print('\t', msg)

    socket.send(''.encode('UTF-8'))

main()

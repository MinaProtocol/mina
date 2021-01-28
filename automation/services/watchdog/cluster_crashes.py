import zmq
import json
import random
import os

def main():
  context = zmq.Context()
  socket = context.socket(zmq.REQ)

  watchdog_addr = os.environ['WATCHDOG_SERVER_PORT']
  socket.connect(watchdog_addr)

  obj = {
    "type": "gauge",
    "metric": "cluster_crashes",
    "value": random.random()
  }

  socket.send(json.dumps(obj).encode('UTF-8'))

main()

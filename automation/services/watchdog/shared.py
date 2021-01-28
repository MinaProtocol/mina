import zmq
import json
import os
from kubernetes import client, config, stream

def get_kubernetes():
  if os.environ.get('LOCAL_KUBERNETES') is not None:
    config.load_kube_config()
    namespace = os.environ.get('KUBERNETES_NAMESPACE')
  else:
    config.load_incluster_config()
    with open('/var/run/secrets/kubernetes.io/serviceaccount/namespace', 'r') as f:
      namespace = f.read()
  v1 = client.CoreV1Api()
  return v1, namespace

def send_obj(obj):
  context = zmq.Context()
  socket = context.socket(zmq.REQ)

  watchdog_addr = os.environ['WATCHDOG_SERVER_PORT']
  socket.connect(watchdog_addr)

  socket.send(json.dumps(obj).encode('UTF-8'))

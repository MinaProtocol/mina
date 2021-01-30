import json
import os
from kubernetes import client, config, stream
import sys
import traceback
import asyncio

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

async def run_periodically(fn, seconds_between, error_counter):
  while True:
    try:
      fn()
    except Exception as e:
      exc_type, exc_obj, exc_tb = sys.exc_info()
      trace = traceback.format_exc()
      error_counter.inc()
      print(trace)

    await asyncio.sleep(seconds_between)

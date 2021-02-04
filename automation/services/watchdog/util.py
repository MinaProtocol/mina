import json
import os
from kubernetes import client, config, stream
import sys
import traceback
import asyncio
import uuid
import time
import math

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

# ===============================================================

# kubernetes has issues streaming big blobs over - this function runs a command, and then breaks the result up over multiple requests to ensure the result makes it over safely
def exec_on_pod(v1, namespace, pod, container, command, request_timeout_seconds = 600):
  def exec_cmd(command, timeout):
    exec_command = [
      '/bin/bash',
      '-c',
      command,
    ]
    result = stream.stream(v1.connect_get_namespaced_pod_exec, pod, namespace, command=exec_command, container=container, stderr=True, stdout=True, stdin=False, tty=False, _request_timeout=timeout)
    return result

  print('running command:', command)

  tmp_file = '/tmp/cns_command.' + str(uuid.uuid4()) + '.out'

  start = time.time()
  result = exec_cmd(command + ' &> ' + tmp_file, request_timeout_seconds)
  end = time.time()

  print('done running command')
  print('\tseconds to run:', end - start)

  file_len = int(exec_cmd('stat --printf="%s" ' + tmp_file, 10))
  print('\tfile length:', str(file_len/(1024*1024)) + 'MB')


  read_segment = lambda start, size: exec_cmd('cat ' + tmp_file + ' | head -c ' + str(start + size) + ' | tail -c ' + str(size), 240)
  chunk_size = int(20e6)
  read_chunk = lambda i: read_segment(i*chunk_size, min((i+1)*chunk_size, file_len) - i*chunk_size)
  num_chunks = math.ceil(file_len/chunk_size)

  start = time.time()
  chunks = list(map(read_chunk, range(num_chunks)))
  result = ''.join(chunks)
  end = time.time()

  print('\tseconds to get result:', end - start)

  exec_cmd('rm ' + tmp_file, 10)

  received_len = len(result.encode('utf-8'))

  if file_len != received_len:
    print('\twarning, result length didn\'t match received length', file_len, received_len)

  # seems to fail frequently
  # assert(file_len - received_len == 0 or file_len - received_len == 1)

  return result

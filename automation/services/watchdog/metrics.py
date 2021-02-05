
import itertools
import datetime
import util
import asyncio
import random
import os
import sys
import traceback
import subprocess
import time
import json
import urllib.request
import ast

from google.cloud import storage

# ========================================================================

def collect_cluster_crashes(v1, namespace, cluster_crashes):
  print('collecting cluster crashes / restarts')
  pods = v1.list_namespaced_pod(namespace, watch=False)

  containers = list(itertools.chain(*[ pod.to_dict()['status']['container_statuses'] for pod in pods.items ]))
  mina_containers = list(filter(lambda c: c['name'] in [ 'coda', 'seed', 'coordinator' ], containers))

  def restarted_recently(c):

    if c['restart_count'] == 0:
      return False

    terminated = c['last_state']['terminated']
    if terminated is None:
      return False

    restart_time = terminated['started_at']
    retart_age_seconds = (datetime.datetime.now(datetime.timezone.utc) - restart_time).total_seconds()

    # restarted less than 30 minutes ago
    return retart_age_seconds <= 30*60

  recently_restarted_containers = list(filter(lambda c: restarted_recently(c), mina_containers))

  fraction_recently_restarted = len(recently_restarted_containers)/len(mina_containers)
  print(len(recently_restarted_containers), 'of', len(mina_containers), 'recently restarted')

  cluster_crashes.set(fraction_recently_restarted)

# ========================================================================

from telemetry_metrics import collect_telemetry_metrics

# ========================================================================

def check_google_storage_bucket(v1, namespace, recent_google_bucket_blocks):
  print('checking google storage bucket')

  bucket = 'mina_network_block_data'
  now = time.time()

  storage_client = storage.Client()
  blobs = list(storage_client.list_blobs(bucket, prefix=namespace))

  blob_ages = [ now - b.generation/1e6 for b in blobs ]

  newest_age = min([ age for age in blob_ages ])

  recent_google_bucket_blocks.set(newest_age)

# ========================================================================

def check_seed_list_up(v1, namespace, seeds_reachable):
  print('checking seed list up')

  seed_peers_list_url = os.environ.get('SEED_PEERS_URL')

  with urllib.request.urlopen(seed_peers_list_url) as f:
    contents = f.read().decode('utf-8')

  seeds =  ' '.join(contents.split('\n'))

  command = 'check_libp2p/check_libp2p ' + seeds
  proc = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, text=True)
  res = json.loads(proc.stdout.read())

  fraction_up = sum(res.values())/len(res.values())

  seeds_reachable.set(fraction_up)

# ========================================================================


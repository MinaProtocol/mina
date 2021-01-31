
import itertools
import datetime
import util
import asyncio
import sys
import traceback
import subprocess
import time

from google.cloud import storage

# ========================================================================

def collect_cluster_crashes(v1, namespace, cluster_crashes):
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

def collect_telemetry_metrics(v1, namespace, nodes_synced_near_best_tip, nodes_synced, prover_errors):
  print('ctm')

  # select a seed at random
  # call telemetry on that seed in a loop with a max number of tries
  # collect info for each metric

  pass

# ========================================================================

def check_google_storage_bucket(v1, namespace, recent_google_bucket_blocks):

  bucket = 'mina_network_block_data'
  now = time.time()

  storage_client = storage.Client()
  blobs = list(storage_client.list_blobs(bucket, prefix=namespace))

  blob_ages = [ now - b.generation/1e6 for b in blobs ]

  newest_age = min([ age for age in blob_ages ])

  recent_google_bucket_blocks.set(newest_age)

# ========================================================================

def check_seed_list_up(v1, namespace, seeds_reachable):

  # get the seed list
  # run a go process that uses libp2p ping
  # https://docs.libp2p.io/tutorials/getting-started/go/#let-s-play-ping-pong

  # collect info for each metric

  print('cslu')
  pass

# ========================================================================


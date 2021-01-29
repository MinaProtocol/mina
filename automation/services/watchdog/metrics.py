
import itertools
import datetime
import util
import asyncio
import sys
import traceback

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
  pass

# ========================================================================

def check_google_storage_bucket(v1, namespace, recent_google_bucket_blocks):
  print('cgsb')
  pass

# ========================================================================

def check_seed_list_up(v1, namespace, seeds_reachable):
  print('cslu')
  pass

# ========================================================================


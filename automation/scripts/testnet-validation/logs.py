from google.cloud import logging as glogging
from kubernetes import client, config
import logging
from datetime import datetime, timedelta
import sys
import time

def fetch_logs(namespace="default", hours_ago=1, log_filter="", max_entries=1000):
  # Python Logging Config
  
  logger = logging.getLogger()

  #Stackdriver Client
  stackdriver_client = glogging.Client()

  # Create some filter expressions 
  earliest_timestamp = datetime.now() - timedelta(hours=int(hours_ago))
  earliest_timestamp_formatted = earliest_timestamp.strftime("%Y-%m-%dT%H:%M:%SZ")
  FILTER_COMMON = """
  timestamp >= "{}"
  resource.type="k8s_container"
  resource.labels.namespace_name="{}"
  """.format(earliest_timestamp_formatted, namespace)

  logger.debug("Common Filter: \n{}".format(FILTER_COMMON))

  logger.info("Checking Logs for {} -- Past {} Hours".format(namespace, hours_ago))
  logger.info(f"Fetching {max_entries} Log Entries")
  # Query for rebroadcasted blocks and insert them into the trie
  logger.info("Filter: \n{}".format(log_filter))
  log_iterator = stackdriver_client.list_entries(filter_=FILTER_COMMON + log_filter)

  logs = []
  for index, log in enumerate(log_iterator):
    logger.debug(log)
    logs.append(log)
    if (index+1) % max_entries == 0:
      break

    if (index+1) % 100 == 0: 
      logger.debug(f"Fetched {index+1} logs")
    # Google API Rate-Limit
    time.sleep(.04)
  logger.debug(f"{len(logs)} logs retrieved")
  return logs
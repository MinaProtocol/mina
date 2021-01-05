import click
import json
import sys
import logging
import collections
from datetime import datetime, timedelta
from google.cloud import logging as glogging

from kubernetes import client, config
from kubernetes.stream import stream


@click.command()
@click.option('--namespace',
              default="hangry-lobster",
              help='Namespace to Query.')
@click.option('--hours-ago',
              default="1",
              help='Consider logs generated between <hours-ago> and now.')
@click.option('--skip-crashes', default=False, help="Should skip checking for crashes.", is_flag=True)
@click.option('--skip-proofs', default=False, help="Should skip checking for proof availability.", is_flag=True)
@click.option('--skip-snark-work', default=False, help="Should skip checking for submitted SNARK Work.", is_flag=True)
def check(namespace, hours_ago, skip_crashes, skip_proofs, skip_snark_work):
    #Stackdriver Client
    stackdriver_client = glogging.Client()
    # Python Logging Config
    logging.basicConfig(stream=sys.stdout, level=logging.INFO)
    logger = logging.getLogger()
    # K8s Config
    config.load_kube_config()

    # Get all the pods in the specified namespace
    v1 = client.CoreV1Api()
    pods = v1.list_namespaced_pod(namespace)
    items = pods.items

    # Create some filter expressions 
    earliest_timestamp = datetime.now() - timedelta(hours=int(hours_ago))
    earliest_timestamp_formatted = earliest_timestamp.strftime("%Y-%m-%dT%H:%M:%SZ")
    FILTER_COMMON = """
    timestamp >= "{}"
    resource.type="k8s_container"
    resource.labels.namespace_name="{}"
    """.format(earliest_timestamp_formatted, namespace)

    logger.debug("Common Filter: \n{}".format(FILTER_COMMON))

    CRASH_FILTER = ' "Unhandled top-level exception:"'
    PROOFS_FILTER = ' "Number of proofs ready for purchase:"'
    SNARK_WORK_FILTER = ' "Submitted completed SNARK work to $address"'

    logger.info("Checking Logs for {} -- Past {} Hours".format(namespace, hours_ago))
    
    logger.debug("SNARK Work Filter: \n{}".format(SNARK_WORK_FILTER))

    # TESTS:
    # Check for any Crashes
    if not skip_crashes:
        logger.info("Checking for Crash Logs")
        logger.debug("Crash Filter: \n{}".format(CRASH_FILTER))
        crash_iterator = stackdriver_client.list_entries(filter_=FILTER_COMMON + CRASH_FILTER)

        nCrashes = 0
        for entry in crash_iterator:  # API call(s)
            logger.debug(json.dumps(entry, indent=2, default=str))
            nCrashes += 1

        logger.info("{} Crashes During the inspected timespan.".format(nCrashes))

    # Check to see if Block Producers are seeing proofs and transactions
    if not skip_proofs:
        logger.info("Checking Proof Availability")
        logger.debug("Proofs Filter: \n{}".format(PROOFS_FILTER))
        proof_log_iterator = stackdriver_client.list_entries(filter_=FILTER_COMMON + PROOFS_FILTER)

        nProofLogs = 0
        available_proof_counter = collections.Counter()
        block_producer_counter = collections.Counter()
        
        for entry in proof_log_iterator:  # API call(s)
            labels = entry[1]
            log = entry[-1]
            logger.debug(json.dumps(log, indent=2, default=str))
            available_proof_counter.update([str((log["metadata"]["proof_count"],log["metadata"]["txn_count"]))])
            block_producer_counter.update([labels["k8s-pod/app"]])
            nProofLogs += 1

        logger.info("Inspected {} Log Entries.".format(nProofLogs))
        logger.info(json.dumps({"Available Proof/Available Transaction Counts": available_proof_counter}, indent=1))
        logger.info(json.dumps({"Blocks Produced": block_producer_counter}, indent=1, sort_keys=True))


    # Check to see if SNARK Workers are submitting SNARK Work
    if not skip_snark_work:
        logger.info("Checking if SNARK Workers are Submitting Proofs")
        logger.debug("SNARK Work Filter: \n{}".format(SNARK_WORK_FILTER))
        snark_work_iterator = stackdriver_client.list_entries(filter_=FILTER_COMMON + SNARK_WORK_FILTER)
        snark_work_counter = collections.Counter()

        nSNARKLogs = 0
        
        for entry in snark_work_iterator:  # API call(s)
            log = entry[1]
            logger.debug(json.dumps(log, indent=2, default=str))
            snark_work_counter.update([log["k8s-pod/app"]])
            nSNARKLogs += 1

        logger.info("Inspected {} Log Entries.".format(nSNARKLogs))
        logger.info(json.dumps({"Snark Work Submitted": snark_work_counter}, indent=2))

    # Check for Failure Conditions
    if not skip_crashes:
        if nCrashes > 0:
            sys.exit(1)
    
if __name__ == '__main__':
    check()

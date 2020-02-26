#!/usr/bin/env python3

# script to find common best-tip prefix over a list of nodes using GraphQL query

import os
import sys
import json

from kubernetes import client, config

import CodaClient

def main (namespace) :
    config.load_kube_config()

    v1 = client.CoreV1Api()
    pods = v1.list_pod_for_all_namespaces(watch=False)

    common_prefix = None

    for pod in pods.items :
        if pod.metadata.namespace == namespace and 'block-producer' in pod.metadata.name :
            print ('Trying query on ' + pod.metadata.name + ' at IP ' + pod.status.pod_ip)
            coda = CodaClient.Client (graphql_host=pod.status.pod_ip)
            result = coda._send_query (query="query bestChainQuery { bestChain { stateHash } }")
            chain = result['data']['bestChain']
            if common_prefix is None :
                common_prefix = chain
            else :
                common_prefix = os.path.commonprefix ([chain,common_prefix])

    print (common_prefix)
        
if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: %s namespace" % sys.argv[0], file=sys.stderr)
        sys.exit(1)

    main(sys.argv[1])

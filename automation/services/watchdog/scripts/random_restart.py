#!/usr/bin/env python3

import sys
import argparse
import time
import random

from kubernetes import client, config

def main():
    parser = argparse.ArgumentParser(description="Periodically kill a random node in a testnet")
    parser.add_argument("-n", "--namespace", help="testnet namespace", required=True, type=str, dest="namespace")
    parser.add_argument("-i", "--interval", help="how often (in minutes) to kill a pod", required=True, type=int, dest="interval")
    parser.add_argument("-ic", "--incluster", help="if we're running from inside the cluster", required=False, default=False, type=bool, dest="incluster")


    args = parser.parse_args(sys.argv[1:])

    if args.incluster:
        config.load_incluster_config()
        assert(args.namespace == '')
        with open('/var/run/secrets/kubernetes.io/serviceaccount/namespace', 'r') as f:
            args.namespace = f.read()
    else:
        config.load_kube_config()
    v1 = client.CoreV1Api()

    while True:
        pods = v1.list_namespaced_pod(args.namespace, watch=False)

        pod_names = [ p.metadata.name for p in pods.items ]
        nodes = [ n for n in pod_names if 'fish' in n or 'whale' in n ]

        if len(nodes) > 0:
            random_node = random.choice(nodes)
            print('restarting', random_node)
            response = v1.delete_namespaced_pod(random_node, args.namespace)

        time.sleep(60 * args.interval)

if __name__ == "__main__":
    main()

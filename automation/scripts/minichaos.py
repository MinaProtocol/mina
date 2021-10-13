#!/usr/bin/env python3

# This tool uses the kubernetes API to destroy some pods every once in a while.
# It tries to avoid killing whales too often, to keep their stake online.
#
# Using pumba https://github.com/alexei-led/pumba would be more robust,
# but possibly less customizable.

import sys
import argparse
import time
import random

from kubernetes import client, config

def main():
    parser = argparse.ArgumentParser(description="Occasionally kill some pods in a testnet")
    parser.add_argument("-n", "--namespace", help="testnet namespace (eg, hangry-lobster)", required=True, type=str, dest="namespace")
    parser.add_argument("-i", "--interval", help="how often (in minutes) to kill a pod", required=True, type=int, dest="interval")

    args = parser.parse_args(sys.argv[1:])

    config.load_kube_config()
    v1 = client.CoreV1Api()

    intervals_since_whale_killed = 20 # start off thinking we're allowed to kill a whale

    while True:
        intervals_since_whale_killed += 1

        pods_up = v1.list_namespaced_pod(args.namespace, watch=False)
        random_pod = random.choice(pods_up.items)

        if 'whale' in random_pod.metadata.name:
            if intervals_since_whale_killed < 20:
                print("Not killing a whale just yet!")
                # decrement because we aren't sleeping in this iteration
                intervals_since_whale_killed -= 1 
                continue
            else:
                intervals_since_whale_killed = 0

        print("Deleting pod %s ..." % random_pod.metadata.name)


        response = v1.delete_namespaced_pod(random_pod.metadata.name, args.namespace)

        print(response)

        time.sleep(60 * args.interval)


if __name__ == "__main__":
    main()

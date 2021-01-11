#!/bin/sh

set -e

namespace="$1"
[ -n "$namespace" ] || (echo 'MISSING ARGUMENT' && exit 1)


seed=$(kubectl get pods -n $namespace | grep 'seed' | sed -n '1 p' | awk '{print $1;}');


kubectl exec $seed -n $namespace -c coda-network-services -- /bin/bash -c "kill \$(ls /proc | grep -v [a-z] | tr '\n' ' ')"

#!/bin/bash

namespace=$1
pod=$(kubectl get pods -n $namespace | grep 'whale' | sed -n '2 p' | awk '{print $1;}')
echo $pod

kubectl -n $namespace exec -c coda -i $pod -- cat /config/daemon.json > daemon.json

#!/bin/bash

CLUSTER="gke_o1labs-192920_us-east1_coda-infra-east"
NAMESPACE="zagreb"

k() {
  kubectl --cluster "$CLUSTER" --namespace "$NAMESPACE" "$@"
}

PODS=$(k get pods | egrep Running | awk '{ print $1 }' | egrep -v NAME | egrep 'producer|coordinator|seed|archive-node-dev')

for POD in $PODS; do
  CONTAINER_FLAGS=""

  if [[ "$POD" == *producer* ]]; then
    CONTAINER_FLAGS="-c coda"
  elif [[ "$POD" == *seed* ]]; then
    CONTAINER_FLAGS="-c seed"
  fi

  LOCAL_IP=$(k $CONTAINER_FLAGS exec -it "$POD" -- bash -c \
    "cat /proc/net/fib_trie | grep -e '|-- 10.' | head -n2 | tail -n1 | sed 's/^[^0-9]*\([0-9\.]\+\).*\r?$/\1/g'")
  EXTERNAL_IP=$(k $CONTAINER_FLAGS exec -it "$POD" -- bash -c \
    "coda client status | grep 'External IP' | sed 's/.* //g' | sed 's/\r//g'")
  PEERS=$(k $CONTAINER_FLAGS exec -it "$POD" -- bash -c \
    "coda client status | grep Peers | sed 's/.*(//g' | sed 's/)//g'")

  echo $POD
  echo $LOCAL_IP
  echo $EXTERNAL_IP
  echo $PEERS
  echo ""
done

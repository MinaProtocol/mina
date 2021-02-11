#!/bin/bash

# archive-node-{1..3}
# fish-block-producer-{1..5}
# whale-block-producer-{1..15}

for node in fish-block-producer-{1..3}; do
  kubectl patch deploy/${node} -p "$(cat patch.yaml)"
  ready=""
  while [[ -z $ready ]]; do
    ready=$(kubectl get pods -l app=${node} | grep -P '\s+([1-9]+)\/\1\s+')
    kubectl get pods -l app=${node}
    sleep 30
    # Uncomment to short-cut the readiness check for slow-to-ready containers
    # ready="true"
  done
done

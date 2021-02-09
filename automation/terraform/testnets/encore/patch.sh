#!/bin/bash

# archive-node-{1..3}
# fish-block-producer-{3..5}

for node in whale-block-producer-{10..15}; do
  kubectl patch deploy/${node} -p "$(cat patch.yaml)"
  ready=""
  while [[ -z $ready ]]; do
    ready=$(kubectl get pods -l app=${node} | grep -P '\s+([1-9]+)\/\1\s+')
    kubectl get pods -l app=${node}
    sleep 30
  done
done

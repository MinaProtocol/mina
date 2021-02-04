#!/bin/bash

# archive-node-{1..3}

for whale in fish-block-producer-{1..5} whale-block-producer-{1..15}; do
  kubectl patch deploy/${whale} -p "$(cat patch.yaml)"
  ready=""
  while [[ -z $ready ]]; do
    ready=$(kubectl get pods -l app=${whale} | grep -P '\s+([1-9]+)\/\1\s+')
    kubectl get pods -l app=${whale}
    sleep 30
  done
done

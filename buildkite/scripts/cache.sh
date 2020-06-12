#!/bin/bash

set -eou pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <save|restore> key path"
  exit 1
fi

MODE=$1
KEY=$2
DEST=$3

if [[ "$MODE" == "save" ]]; then
  tar cvf "$KEY.tar" "$DEST"
  buildkite-agent artifact upload "$KEY.tar" "gs://buildkite_k8s/coda/shared"
elif [[ "$MODE" == "restore" ]]; then
  # restoring may fail if cache miss
  buildkite-agent artifact download "$KEY.tar" . || true
  tar xvf "$KEY.tar" "$DEST" || true
fi



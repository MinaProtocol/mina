#!/bin/bash

set -eou pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <save|restore> key path"
  exit 1
fi

MODE=$1
KEY=$2
PATH=$3

if [[ "$MODE" == "save" ]]; then
  tar cvf "$KEY.tar" "$PATH"
  buildkite-agent artifact upload "$KEY.tar" "gs://buildkite/coda/shared"
elif [[ "$MODE" == "restore" ]]; then
  # restoring may fail if cache miss
  gsutil -o GSUtil:parallel_composite_upload_threshold=100M -q cp "$KEY.tar" "." || true
  tar xvf "$KEY.tar" "$PATH" || true
fi



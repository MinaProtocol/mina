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
  zip -r "$KEY.zip" "$DEST"
  ~/.buildkite-agent/bin/buildkite-agent artifact upload "$KEY.zip" "gs://buildkite_k8s/coda/shared"
elif [[ "$MODE" == "restore" ]]; then
  # restoring may fail if cache miss
  ~/.buildkite-agent/bin/buildkite-agent artifact download "$KEY.zip" . || true
  unzip "$KEY.zip" "$DEST" || true
fi



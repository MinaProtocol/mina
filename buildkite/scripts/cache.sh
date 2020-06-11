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
  zip -r "$KEY.zip" "$PATH"
  buildkite-agent artifact upload "$KEY.zip" "gs://buildkite/coda/shared"
elif [[ "$MODE" == "restore" ]]; then
  # restoring may fail if cache miss
  buildkite-agent artifact download "$KEY.zip" . || true
  unzip "$KEY.zip" "$PATH" || true
fi



#!/bin/bash

set -eou pipefail
set +x

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <remote-folder> <file or regexp>"
  exit 1
fi

DOWNLOAD_BIN=gsutil
PREFIX=gs://buildkite_k8s/coda/shared/${BUILDKITE_JOB_ID}
FILE="$1"
REMOTE_LOCATION="$2"

$DOWNLOAD_BIN cp "${PREFIX}/${REMOTE_LOCATION}/${FILE}" .

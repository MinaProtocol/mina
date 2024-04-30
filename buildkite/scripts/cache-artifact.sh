#!/bin/bash

set -eou pipefail
set +x

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <path-to-file> <remote-folder>"
  exit 1
fi

UPLOAD_BIN=gsutil
PREFIX=gs://buildkite_k8s/coda/shared/${BUILDKITE_JOB_ID}
FILE="$1"
REMOTE_LOCATION="$2"

$UPLOAD_BIN cp "${FILE}" "${PREFIX}/${REMOTE_LOCATION}"


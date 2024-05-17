#!/bin/bash

set -eou pipefail
set +x

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <path-to-file> <remote-folder>"
  exit 1
fi

UPLOAD_BIN=gsutil
PREFIX=gs://buildkite_k8s/coda/shared/${BUILDKITE_BUILD_ID}
FILE="$1"
REMOTE_LOCATION="$2"

if [[ -v GS_DO_NOT_OVERRIDE ]]; then 
  EXTRA_FLAGS="-n"
else 
  EXTRA_FLAGS=""
fi

$UPLOAD_BIN cp ${EXTRA_FLAGS} "${FILE}" "${PREFIX}/${REMOTE_LOCATION}"


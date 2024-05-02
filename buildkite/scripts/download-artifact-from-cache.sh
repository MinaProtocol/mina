#!/bin/bash

set -eou pipefail
set +x

if [[ $# -lt 2 ]]; then
  echo "Usage: download-artifact-from-cache.sh <remote-folder> <file or regexp> [gsutil opts]"
  exit 1
fi

DOWNLOAD_BIN=gsutil
PREFIX=gs://buildkite_k8s/coda/shared/${BUILDKITE_BUILD_ID}
FILE="$1"
REMOTE_LOCATION="$2"
OPTS=${3}

$DOWNLOAD_BIN cp ${OPTS} "${PREFIX}/${REMOTE_LOCATION}/${FILE}" .

#!/bin/bash

set -eou pipefail
set -x

if [[ $# -lt 2 ]]; then
  echo "Usage: download-artifact-from-cache.sh <remote-folder> <file or regexp> [gsutil opts]"
  exit 1
fi

DOWNLOAD_BIN=gsutil
PREFIX=gs://buildkite_k8s/coda/shared/0193492f-2c3f-4dde-8e38-b1c9c36ccab5
FILE="$1"
REMOTE_LOCATION="$2"
OPTS=${3:-""}
TARGET=${4:-"."}

$DOWNLOAD_BIN cp ${OPTS} "${PREFIX}/${REMOTE_LOCATION}/${FILE}" $TARGET

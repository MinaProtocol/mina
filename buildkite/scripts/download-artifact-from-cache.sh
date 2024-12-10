#!/bin/bash

set -eou pipefail
set -x

if [[ $# -lt 2 ]]; then
  echo "Usage: download-artifact-from-cache.sh <remote-folder> <file or regexp> [gsutil opts]"
  exit 1
fi

DOWNLOAD_BIN=gsutil
PREFIX=gs://buildkite_k8s/coda/shared/019365c5-e59b-4d54-941c-3d0f5adde52c
FILE="$1"
REMOTE_LOCATION="$2"
OPTS=${3:-""}
TARGET=${4:-"."}

$DOWNLOAD_BIN cp ${OPTS} "${PREFIX}/${REMOTE_LOCATION}/${FILE}" $TARGET

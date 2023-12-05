#!/bin/bash

set -eou pipefail
set +x

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <path-to-file> <miss-in-docker-cmd>"
  exit 1
fi

FILE="$1"
MISS_CMD="$2"

set +e
if [[ -f "${FILE}" ]] || $UPLOAD_BIN cp "${PREFIX}/${FILE}" .; then
  set -e
  echo "*** Cache Hit -- skipping step ***"
else
  set -e
  echo "*** Cache miss -- executing step ***"
  bash -c "$MISS_CMD"
  source buildkite/scripts/cache-artifact.sh "${FILE}" "${PREFIX}/${FILE}"
fi


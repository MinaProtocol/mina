#!/bin/bash
set -o pipefail -x

TEST_NAME="$1"
CODA_IMAGE="gcr.io/o1labs-192920/coda-daemon-puppeteered:$CODA_VERSION-$CODA_GIT_HASH"

./test_executive.exe cloud "$TEST_NAME" \
  --coda-image "$CODA_IMAGE" \
  --coda-automation-location ./automation \
  | tee "$TEST_NAME.test.log" \
  | coda-logproc -i inline -f '!(.level in ["Debug", "Spam"])'

#!/bin/bash
set -o pipefail -x

TEST_NAME="$1"
MINA_IMAGE="gcr.io/o1labs-192920/mina-daemon-puppeteered:$MINA_VERSION-devnet"
ARCHIVE_IMAGE="gcr.io/o1labs-192920/mina-archive:$MINA_VERSION"

./test_executive.exe cloud "$TEST_NAME" \
  --coda-image "$MINA_IMAGE" \
  --archive-image "$ARCHIVE_IMAGE" \
  --coda-automation-location ./automation \
  | tee "$TEST_NAME.test.log" \
  | coda-logproc -i inline -f '!(.level in ["Debug", "Spam"])'

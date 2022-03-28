#!/bin/bash
set -o pipefail -x

TEST_NAME="$1"
MINA_IMAGE="gcr.io/o1labs-192920/mina-daemon:$MINA_DOCKER_TAG-devnet"
ARCHIVE_IMAGE="gcr.io/o1labs-192920/mina-archive:$MINA_DOCKER_TAG"

if [[ "${TEST_NAME:0:4}" == "opt-" ]] && [[ "$RUN_OPT_TESTS" == "" ]]; then
  echo "Skipping $TEST_NAME"
  exit 0
fi

# if [[ "$TEST_NAME" == "snarkyjs" ]]; then
#   echo "--- install node"
#   curl -sL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
#   sudo apt install -y nodejs
# fi

./test_executive.exe cloud "$TEST_NAME" \
  --mina-image "$MINA_IMAGE" \
  --archive-image "$ARCHIVE_IMAGE" \
  --mina-automation-location ./automation \
  | tee "$TEST_NAME.test.log" \
  | ./logproc.exe -i inline -f '!(.level in ["Debug", "Spam"])'

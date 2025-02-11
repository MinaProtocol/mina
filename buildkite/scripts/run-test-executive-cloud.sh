#!/bin/bash
set -o pipefail -x

TEST_NAME="$1"
MINA_IMAGE="gcr.io/o1labs-192920/mina-daemon:$MINA_DOCKER_TAG-devnet"
ARCHIVE_IMAGE="gcr.io/o1labs-192920/mina-archive:$MINA_DOCKER_TAG"

if [[ "${TEST_NAME:0:15}" == "block-prod-prio" ]] && [[ "$RUN_OPT_TESTS" == "" ]]; then
  echo "Skipping $TEST_NAME"
  exit 0
fi

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

echo "deb [trusted=yes] https://apt.releases.hashicorp.com $MINA_DEB_CODENAME main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y "terraform"

source buildkite/scripts/debian/install.sh "mina-test-executive"

mina-test-executive cloud "$TEST_NAME" \
  --mina-image "$MINA_IMAGE" \
  --archive-image "$ARCHIVE_IMAGE" \
  --mina-automation-location ./automation \
  | tee "$TEST_NAME.test.log" \
  | mina-logproc -i inline -f '!(.level in ["Debug", "Spam"])'

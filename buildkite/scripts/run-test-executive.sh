#!/bin/bash
set -o pipefail -x

TEST_NAME="$1"

MINA_IMAGE="gcr.io/o1labs-192920/mina-daemon:$MINA_DOCKER_TAG-berkeley"
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

echo "Installing mina daemon package: mina-test-executive=${MINA_DEB_VERSION}"
echo "deb [trusted=yes] http://packages.o1test.net $MINA_DEB_CODENAME $MINA_DEB_RELEASE" | tee /etc/apt/sources.list.d/mina.list
apt-get update
apt-get install --allow-downgrades -y "mina-test-executive=$MINA_DEB_VERSION" "mina-logproc=$MINA_DEB_VERSION"

mina-test-executive cloud "$TEST_NAME" \
  --mina-image "$MINA_IMAGE" \
  --archive-image "$ARCHIVE_IMAGE" \
  --mina-automation-location ./automation \
  | tee "$TEST_NAME.test.log" \
  | mina-logproc.exe -i inline -f '!(.level in ["Debug", "Spam"])' 

EXIT_CODE="$?"

./buildkite/scripts/upload-test-results.sh $TEST_NAME


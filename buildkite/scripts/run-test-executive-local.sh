#!/bin/bash
set -o pipefail -x

TEST_NAME="$1"

MINA_IMAGE="gcr.io/o1labs-192920/mina-daemon:$MINA_DOCKER_TAG-berkeley"
ARCHIVE_IMAGE="gcr.io/o1labs-192920/mina-archive:$MINA_DOCKER_TAG"

TE_DEB_VERSION="2.0.0rampup3-abstract-engine-5bbaf69"

if [[ "${TEST_NAME:0:15}" == "block-prod-prio" ]] && [[ "$RUN_OPT_TESTS" == "" ]]; then
  echo "Skipping $TEST_NAME"
  exit 0
fi

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git apt-transport-https ca-certificates tzdata curl

TESTNET_NAME="berkeley"

git config --global --add safe.directory /workdir

echo "Installing mina daemon package: mina-test-executive"
echo "deb [trusted=yes] http://packages.o1test.net ubuntu stable" | tee /etc/apt/sources.list.d/mina.list
apt-get update
apt-get install -y "minimina"

echo "deb [trusted=yes] https://apt.releases.hashicorp.com $MINA_DEB_CODENAME main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y "terraform" "docker" "docker-compose-plugin" "docker-ce"

echo "Installing mina daemon package: mina-test-executive=${TE_DEB_VERSION}"
echo "deb [trusted=yes] http://packages.o1test.net $MINA_DEB_CODENAME $MINA_DEB_RELEASE" | tee /etc/apt/sources.list.d/mina.list
apt-get update
apt-get install --allow-downgrades -y "mina-test-executive=$TE_DEB_VERSION" "mina-logproc=$TE_DEB_VERSION"

git clone https://github.com/MinaFoundation/lucy-keypairs.git

export MINIMINA_HOME=$PWD/minimina-home

mkdir -p $MINIMINA_HOME

mina-test-executive abstract "$TEST_NAME" \
  --network-runner /usr/bin/minimina \
  --config ./automation/integration-tests/minimina.json \
  --keypairs-path lucy-keypairs \
  --mina-image "$MINA_IMAGE" \
  --archive-image "$ARCHIVE_IMAGE" \
  --mina-automation-location ./automation \
  | tee "$TEST_NAME.test.log" \
  | mina-logproc -i inline -f '!(.level in ["Debug", "Spam"])'

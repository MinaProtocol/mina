#!/bin/bash

set -eo pipefail

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git apt-transport-https ca-certificates tzdata curl python3

case "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" in
  rampup|berkeley|release/2.0.0|develop|o1js-main)
    TESTNET_NAME="berkeley"
  ;;
  *)
    TESTNET_NAME="mainnet"
esac

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

echo "Installing mina daemon package: mina-${TESTNET_NAME}=${MINA_DEB_VERSION}"
echo "deb [trusted=yes] http://packages.o1test.net $MINA_DEB_CODENAME $MINA_DEB_RELEASE" | tee /etc/apt/sources.list.d/mina.list
apt-get update
apt-get install --allow-downgrades -y "mina-${TESTNET_NAME}=${MINA_DEB_VERSION}"

K=1
MAX_NUM_UPDATES=4
MIN_NUM_UPDATES=2   

echo "--- Run Snark Transaction Profiler with parameters: --zkapps --k ${K} --max-num-updates ${MAX_NUM_UPDATES} --min-num-updates ${MIN_NUM_UPDATES}"
python3 ./scripts/snark_transaction_profiler.py ${K} ${MAX_NUM_UPDATES} ${MIN_NUM_UPDATES}
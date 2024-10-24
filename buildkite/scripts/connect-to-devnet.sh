#!/bin/bash

set -eo pipefail

case "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" in
  compatible|release/*|develop|master)
  ;;
  *)
    echo "Not pulling against mainline branch, not running the connect test"
    exit 0 ;;
esac

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git apt-transport-https ca-certificates tzdata curl

TESTNET_VERSION_NAME="devnet"
TESTNET_NAME="testworld-2-0"

git config --global --add safe.directory /workdir

source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/install.sh "mina-${TESTNET_VERSION_NAME}"

# Remove lockfile if present
rm ~/.mina-config/.mina-lock ||:

mkdir -p /root/libp2p-keys/
# Pre-generated random password for this quick test
export MINA_LIBP2P_PASS=eithohShieshichoh8uaJ5iefo1reiRudaekohG7AeCeib4XuneDet2uGhu7lahf
mina libp2p generate-keypair --privkey-path /root/libp2p-keys/key
# Set permissions on the keypair so the daemon doesn't complain
chmod -R 0700 /root/libp2p-keys/

# Restart in the background
mina daemon \
  --peer-list-url "https://storage.googleapis.com/seed-lists/${TESTNET_NAME}_seeds.txt" \
  --libp2p-keypair "/root/libp2p-keys/key" \
& # -background

# Attempt to connect to the GraphQL client every 30s for up to 12 minutes
num_status_retries=24
for ((i=1;i<=$num_status_retries;i++)); do
  sleep 30s
  set +e
  mina client status
  status_exit_code=$?
  set -e
  if [ $status_exit_code -eq 0 ]; then
    break
  elif [ $i -eq $num_status_retries ]; then
    exit $status_exit_code
  fi
done

# Check that the daemon has connected to peers and is still up after 2 mins
sleep 2m
mina client status
if [ $(mina advanced get-peers | wc -l) -gt 0 ]; then
    echo "Found some peers"
else
    echo "No peers found"
    exit 1
fi


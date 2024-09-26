#!/bin/bash

set -eo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 '<testnet-name>' '<wait-between-polling-graphql>''<wait-after-final-check>'"
    exit 1
fi

TESTNET_NAME=$1
WAIT_BETWEEN_POLLING_GRAPHQL=$2
WAIT_AFTER_FINAL_CHECK=$3

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y git apt-transport-https ca-certificates tzdata curl libwww-perl jq

git config --global --add safe.directory /workdir

source buildkite/scripts/export-git-env-vars.sh

source buildkite/scripts/debian/install.sh "mina-${TESTNET_NAME}" 1

# Remove lockfile if present
sudo rm ~/.mina-config/.mina-lock ||:

sudo mkdir -p /root/libp2p-keys/

# Set permissions on the keypair so the daemon doesn't complain
sudo chmod -R 0700 /root/libp2p-keys/
# Pre-generated random password for this quick test
sudo MINA_LIBP2P_PASS=eithohShieshichoh8uaJ5iefo1reiRudaekohG7AeCeib4XuneDet2uGhu7lahf mina libp2p generate-keypair --privkey-path /root/libp2p-keys/key

# Restart in the background
sudo MINA_LIBP2P_PASS=eithohShieshichoh8uaJ5iefo1reiRudaekohG7AeCeib4XuneDet2uGhu7lahf \
    TESTNET_NAME=$TESTNET_NAME \
  bash -c "mina daemon \
  --peer-list-url \"https://storage.googleapis.com/seed-lists/${TESTNET_NAME}_seeds.txt\" \
  --libp2p-keypair \"/root/libp2p-keys/key\" \
  --seed &" # -background

# Attempt to connect to the GraphQL client every 10s for up to 8 minutes
num_status_retries=24
for ((i=1;i<=$num_status_retries;i++)); do
  sleep $WAIT_BETWEEN_POLLING_GRAPHQL
  set +e
  sudo mina client status
  status_exit_code=$?
  set -e
  if [ $status_exit_code -eq 0 ]; then
    break
  elif [ $i -eq $num_status_retries ]; then
    exit $status_exit_code
  fi
done

peer_retries=10
for ((i=1;i<=$peer_retries;i++)); do
  peer_count=$(sudo mina advanced get-peers | wc -l)
  sudo mina client status

  if [ "$peer_count" -gt 0 ]; then
      echo "Found some peers"
      exit 0;      
  else
      echo "No peers found"
  fi
  sleep $WAIT_AFTER_FINAL_CHECK
done

exit 1;
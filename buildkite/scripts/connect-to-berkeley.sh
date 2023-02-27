#!/bin/sh

set -eo pipefail

case "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" in
  rampup|berkeley|release/2.0.0)
  ;;
  *)
    echo "Not pulling against rampup, not running the connect test"
    exit 0 ;;
esac

git config --global --add safe.directory /workdir

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

# Attempt to connect to the GraphQL client every 10s for up to 4 minutes
status_retry_iterator=0
num_status_retries=24
while [ $status_retry_iterator -lt $num_status_retries ] ; do
  sleep 10s
  set +e
  mina client status
  status_exit_code=$?
  set -e
  if [ $status_exit_code -eq 0 ]; then
    break
  elif [ $i -eq $num_status_retries ]; then
    exit $status_exit_code
  fi
  true $((i=i+1))
done

# Check that the daemon has connected to peers and is still up after 2 mins
sleep 2m
mina client status
if [ $(mina advanced get-peers | wc -l) -gt 0 ]; then
    echo "Found some peers"
el0se
    echo "No peers found"
    exit 1
fi


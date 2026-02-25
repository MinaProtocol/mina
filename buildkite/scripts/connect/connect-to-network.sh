#!/bin/bash

set -eo pipefail

# --- Initialization ---
MINA_DEBIAN_NETWORK=""
NETWORK_NAME=""
WAIT_BETWEEN_POLLING_GRAPHQL=""
WAIT_AFTER_FINAL_CHECK=""

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

All arguments are mandatory:
  --mina-debian-network <val>        Mina debian network name
  --network-name <val>               Testnet name (used for seeds URL and validation)
  --wait-between-polling <val>       Seconds to wait between GraphQL polling
  --wait-after-final-check <val>     Seconds to wait after the final check
  --help                             Display this help message

Example:
  $0 --mina-debian-network devnet --network-name devnet --wait-between-polling 10 --wait-after-final-check 120
EOF
    exit 1
}

# --- Long-Flag Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mina-debian-network)
            MINA_DEBIAN_NETWORK="$2"
            shift 2
            ;;
        --network-name)
            NETWORK_NAME="$2"
            shift 2
            ;;
        --wait-between-polling)
            WAIT_BETWEEN_POLLING_GRAPHQL="$2"
            shift 2
            ;;
        --wait-after-final-check)
            WAIT_AFTER_FINAL_CHECK="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Error: Unknown argument '$1'"
            usage
            ;;
    esac
done

# --- Validation ---
if [[ -z "$MINA_DEBIAN_NETWORK" || -z "$NETWORK_NAME" || -z "$WAIT_BETWEEN_POLLING_GRAPHQL" || -z "$WAIT_AFTER_FINAL_CHECK" ]]; then
    echo "Error: All four required arguments must be provided."
    usage
fi

# --- Main Script Logic ---

git config --global --add safe.directory /workdir

source buildkite/scripts/debian/update.sh --verbose
source buildkite/scripts/export-git-env-vars.sh
source buildkite/scripts/debian/install.sh "mina-${MINA_DEBIAN_NETWORK}" 1

# Remove lockfile if present
rm /home/opam/.mina-config/.mina-lock || true

mkdir -p /home/opam/libp2p-keys/
# Pre-generated random password for this quick test
export MINA_LIBP2P_PASS=eithohShieshichoh8uaJ5iefo1reiRudaekohG7AeCeib4XuneDet2uGhu7lahf
mina libp2p generate-keypair --privkey-path /home/opam/libp2p-keys/key
# Set permissions on the keypair so the daemon doesn't complain
chmod -R 0700 /home/opam/libp2p-keys/

# Start the daemon in the background
mina daemon \
  --peer-list-url "https://storage.googleapis.com/seed-lists/${NETWORK_NAME}_seeds.txt" \
  --libp2p-keypair "/home/opam/libp2p-keys/key" \
&

# Attempt to connect to the GraphQL client every X seconds for 24 retries
num_status_retries=24
for ((i=1;i<=$num_status_retries;i++)); do
    sleep "$WAIT_BETWEEN_POLLING_GRAPHQL"
    set +e
    mina client status
    status_exit_code=$?
    set -e
    
    if [ $status_exit_code -eq 0 ]; then
        break
    elif [ $i -eq $num_status_retries ]; then
        echo "Error: Daemon failed to become responsive after $num_status_retries retries."
        exit $status_exit_code
    fi
done

# Final check for peer connectivity
sleep "$WAIT_AFTER_FINAL_CHECK"
mina client status

if [ "$(mina advanced get-peers | wc -l)" -gt 0 ]; then
    echo "Found some peers"
else
    echo "No peers found"
    exit 1
fi

# Check network id via GraphQL
NETWORK_ID=$(curl -s 'http://localhost:3085/graphql' \
    -H 'accept: application/json' \
    -H 'content-type: application/json' \
    --data-raw '{"query":"query MyQuery {\n  networkID\n}\n","variables":null,"operationName":"MyQuery"}' \
    | jq -r .data.networkID)

EXPECTED_NETWORK="mina:$NETWORK_NAME"

if [[ "$NETWORK_ID" == "$EXPECTED_NETWORK" ]]; then
    echo "Network id correct ($NETWORK_ID)"
else
    echo "Network id incorrect (expected: $EXPECTED_NETWORK, got: $NETWORK_ID)"
    exit 1
fi

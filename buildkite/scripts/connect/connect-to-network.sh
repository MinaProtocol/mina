#!/bin/bash

set -eox pipefail

# --- Initialization ---
MINA_DEBIAN_NETWORK=""
NETWORK_NAME=""
WAIT_BETWEEN_POLLING_GRAPHQL=""
SYNC_TIMEOUT=""
STABLE_VERSION="3.3.0*"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

All arguments are mandatory:
  --mina-debian-network <val>        Mina debian network name
  --network-name <val>               Testnet name (used for seeds URL and validation)
  --wait-between-polling <val>       Duration to wait between GraphQL polling
  --sync-timeout <val>               Duration to wait before considering the sync is failed
  --help                             Display this help message

Example:
  $0 --mina-debian-network devnet --network-name devnet --wait-between-polling 10s --sync-timeout 20min
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
        --sync-timeout)
            SYNC_TIMEOUT="$2"
            shift 2
            ;;
        --stable-version)
            STABLE_VERSION="$2"
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
if [[ -z "$MINA_DEBIAN_NETWORK" || -z "$NETWORK_NAME" || -z "$WAIT_BETWEEN_POLLING_GRAPHQL" || -z "$SYNC_TIMEOUT" ]]; then
    echo "Error: All four required arguments must be provided."
    usage
fi

# --- Main Script Logic ---

git config --global --add safe.directory /workdir

source buildkite/scripts/debian/update.sh --verbose
source buildkite/scripts/export-git-env-vars.sh
source buildkite/scripts/debian/install.sh "mina-${MINA_DEBIAN_NETWORK},mina-daemon-storage-toolbox" 1

# Legacy scanner installs to a separate versioned path under /usr/lib/mina/
FORCE_VERSION="*" ROOT="legacy" ./buildkite/scripts/debian/install.sh "mina-daemon-recovery-storage-toolbox" 1


# Remove lockfile if present
rm /home/opam/.mina-config/.mina-lock || true

mkdir -p /home/opam/libp2p-keys/
# Pre-generated random password for this quick test
export MINA_LIBP2P_PASS=eithohShieshichoh8uaJ5iefo1reiRudaekohG7AeCeib4XuneDet2uGhu7lahf
mina libp2p generate-keypair --privkey-path /home/opam/libp2p-keys/key
# Set permissions on the keypair so the daemon doesn't complain
chmod -R 0700 /home/opam/libp2p-keys/

start_daemon_and_wait_for_sync() {
    local MINA="$1"

    # Start the daemon in the background
    "$MINA" daemon \
      --peer-list-url "https://storage.googleapis.com/seed-lists/${NETWORK_NAME}_seeds.txt" \
      --libp2p-keypair "/home/opam/libp2p-keys/key" \
    &

    DAEMON_PID="$!"

    local deadline
    deadline=$(date -d "+ $SYNC_TIMEOUT" +%s)

    local sync_status=""
    while [ "$(date +%s)" -lt $deadline ]; do
        sync_status=$( { curl -s -m 5 'http://localhost:3085/graphql' \
            -H 'accept: application/json' \
            -H 'content-type: application/json' \
            --data-raw '{"query":"query { syncStatus }"}' \
            | jq -r .data.syncStatus ; } 2>/dev/null || echo "CONNECT_ERROR" )

        if [[ "$sync_status" == "SYNCED" ]]; then
            break
        fi

        sleep "$WAIT_BETWEEN_POLLING_GRAPHQL"
    done

    if [[ "$sync_status" != "SYNCED" ]]; then
        echo "Error: Daemon failed to sync into network withint timeout of $SYNC_TIMEOUT, current status: $sync_status"
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
}

# --- Step 1: Test with current mina ---
start_daemon_and_wait_for_sync mina

# --- Step 2: Stop daemon ---
mina client stop-daemon
wait "$DAEMON_PID"

# --- Step 3: Convert RocksDB to legacy format ---
mina-storage-converter \
    --node-dir /home/opam/.mina-config \
    --current-scanner /usr/lib/mina/storage/10.5.2/3.3.0/mina-rocksdb-scanner \
    --stable-scanner /usr/lib/mina/storage/5.7.12/3.3.0/mina-rocksdb-scanner \
    --yes --verbose

if [[ "$MINA_DEBIAN_NETWORK" == "mainnet" ]]; then
    source buildkite/scripts/debian/install_official.sh --package "mina-mainnet" --channel stable --version "$STABLE_VERSION"
else
    source buildkite/scripts/debian/install_official.sh --package "mina-${MINA_DEBIAN_NETWORK}" --version "$STABLE_VERSION"
fi

# --- Step 4: Test with legacy mina ---
start_daemon_and_wait_for_sync mina

#!/bin/bash

set -eox pipefail

# --- Initialization ---
MINA_DEBIAN_NETWORK=""
NETWORK_NAME=""
WAIT_BETWEEN_POLLING_GRAPHQL=""
SYNC_TIMEOUT=""
STABLE_VERSION="3.3.0"

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

MAINNET_PEERS=(
    "/dns4/mina-mainnet-seed.staketab.com/tcp/10003/p2p/12D3KooWSDTiXcdBVpN12ZqXJ49qCFp8zB1NnovuhZu6A28GLF1J"
    "/dns4/mina-seed.bitcat.network/tcp/10001/p2p/12D3KooWQzozNTDKL7MqUh6Nh11GMA4pQhRCAsNTRWxCAzAi4VbE"
    "/dns4/seed-1.mainnet.gcp.o1test.net/tcp/10003/p2p/12D3KooWCa1d7G3SkRxy846qTvdAFX69NnoYZ32orWVLqJcDVGHW"
    "/dns4/seed-2.mainnet.gcp.o1test.net/tcp/32002/p2p/12D3KooWK4NfthViCTyLgVQa1WvqDC1NccVxGruCXCZUt3GqvFvn"
    "/dns4/seed-3.mainnet.gcp.o1test.net/tcp/32003/p2p/12D3KooWNofeYVAJXA3WGg2qCDhs3GEe71kTmKpFQXRbZmCz1Vr7"
    "/dns4/seed-4.mainnet.gcp.o1test.net/tcp/10003/p2p/12D3KooWEdBiTUQqxp3jeuWaZkwiSNcFxC6d6Tdq7u2Lf2ZD2Q6X"
    "/dns4/seed-5.mainnet.gcp.o1test.net/tcp/32005/p2p/12D3KooWL1DJTigSwuKQRfQE3p7puFUqfbHjXbZJ9YBWtMNpr3GU"
    "/dns4/seed-6.mainnet.gcp.o1test.net/tcp/32006/p2p/12D3KooWHGx4u32n42ub7dJNxAcAhwiA1WDq1Zsjn3k7RsS11pE8"
    "/dns4/seed.minataur.net/tcp/8302/p2p/12D3KooWNyExDzG8T1BYXHpXQS66kaw3zi6qi5Pg9KD3GEyHW5FF"
    "/dns4/seed.piconbello.com/tcp/10001/p2p/12D3KooWRFac2AztcTeen2DYNwnTrmVBvwNDsRiFpDVdTkwdFAHP"
)

start_daemon_and_wait_for_sync() {
    local MINA="$1"

    local -a peer_list_args
    if [[ "$NETWORK_NAME" == "mainnet" ]]; then
        for peer in "${MAINNET_PEERS[@]}"; do
            peer_list_args+=(--peer "$peer")
        done
    else
        peer_list_args=(--peer-list-url "https://bootnodes.minaprotocol.com/networks/${NETWORK_NAME}.txt")
    fi

    # Start the daemon in the background
    "$MINA" daemon \
      "${peer_list_args[@]}" \
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
    --current-scanner /usr/lib/mina/storage/10.5.2/${GITTAG}/mina-rocksdb-scanner \
    --stable-scanner /usr/lib/mina/storage/5.7.12/${STABLE_VERSION}/mina-rocksdb-scanner \
    --yes --verbose

if [[ "$MINA_DEBIAN_NETWORK" == "mainnet" ]]; then
    source buildkite/scripts/debian/install_official.sh --package "mina-mainnet" --channel stable --version "$STABLE_VERSION*"
else
    source buildkite/scripts/debian/install_official.sh --package "mina-${MINA_DEBIAN_NETWORK}" --version "$STABLE_VERSION*"
fi

# --- Step 4: Check sync with legacy mina and shutdown ---
start_daemon_and_wait_for_sync mina
mina client stop-daemon
wait "$DAEMON_PID"

# --- Step 5: Upgrade mina to current ---
source buildkite/scripts/debian/install.sh "mina-${MINA_DEBIAN_NETWORK}" 1

# --- Step 6: Check sync with current mina ---
start_daemon_and_wait_for_sync mina

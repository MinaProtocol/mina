#!/bin/bash

set -eox pipefail

# Connect test: start the current daemon, sync against the live network and
# assert the network id. Binaries (mina, mina-graphql-client, libp2p_helper) are
# restored bare from the apps cache; this job depends on the Apps build, so a
# cache miss is a hard failure.

# --- Initialization ---
MINA_DEBIAN_NETWORK=""
MINA_PROFILE_ARG=""
NETWORK_NAME=""
WAIT_BETWEEN_POLLING_GRAPHQL=""
SYNC_TIMEOUT=""

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

All arguments are mandatory unless noted:
  --mina-debian-network <val>        Mina debian network name
  --mina-profile <val>               Node profile (dev, devnet, lightnet, mainnet)
  --network-name <val>               Testnet name (used for seeds URL and validation)
  --wait-between-polling <val>       Duration to wait between GraphQL polling
  --sync-timeout <val>               Duration to wait before considering the sync is failed
  --peer-list-url <val>              Peer list URL
  --help                             Display this help message

Example:
  $0 --mina-debian-network devnet --mina-profile devnet --network-name devnet --wait-between-polling 10s --sync-timeout 20min
EOF
    exit 1
}

# --- Long-Flag Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mina-debian-network) MINA_DEBIAN_NETWORK="$2"; shift 2 ;;
        --mina-profile) MINA_PROFILE_ARG="$2"; shift 2 ;;
        --network-name) NETWORK_NAME="$2"; shift 2 ;;
        --peer-list-url) PEER_LIST_URL="$2"; shift 2 ;;
        --wait-between-polling) WAIT_BETWEEN_POLLING_GRAPHQL="$2"; shift 2 ;;
        --sync-timeout) SYNC_TIMEOUT="$2"; shift 2 ;;
        --help) usage ;;
        *) echo "Error: Unknown argument '$1'"; usage ;;
    esac
done

# --- Validation ---
if [[ -z "$MINA_DEBIAN_NETWORK" || -z "$MINA_PROFILE_ARG" || -z "$NETWORK_NAME" || -z "$WAIT_BETWEEN_POLLING_GRAPHQL" || -z "$SYNC_TIMEOUT" || -z "$PEER_LIST_URL" ]]; then
    echo "Error: All required arguments must be provided."
    usage
fi

export MINA_PROFILE="$MINA_PROFILE_ARG"

# --- Main Script Logic ---

git config --global --add safe.directory /workdir
source buildkite/scripts/debian/update.sh --verbose
source buildkite/scripts/export-git-env-vars.sh

# The daemon fetches the genesis (and epoch) ledger tarballs referenced by the
# runtime config from S3 when they are not already on disk. Pin the public
# read-only mirror explicitly: this container otherwise inherits
# MINA_LEDGER_S3_BUCKET (a ContainerEnvVars passthrough) from the agent, where it
# is set to the auth-required write bucket for the hardfork pipelines. The
# daemon's unauthenticated curl then 403s and the node crashes with
# "Could not find a ledger tar file for hash ...". The read-only bucket serves
# the devnet/mainnet genesis ledgers anonymously.
export MINA_LEDGER_S3_BUCKET="https://s3-us-west-2.amazonaws.com/snark-keys-ro.o1test.net"

# Restore the current-version binaries bare from the apps cache (mirroring the
# .debs). No .deb fallback: the job depends on the Apps build, not the package
# build, so a cache miss is a hard failure rather than a silent .deb install.
./buildkite/scripts/apps/restore_binary.sh
./buildkite/scripts/apps/restore_app.sh mina_graphql_client_app.exe mina-graphql-client
./buildkite/scripts/apps/restore_app.sh libp2p_helper coda-libp2p_helper
./buildkite/scripts/apps/restore_daemon_config.sh "$MINA_DEBIAN_NETWORK"

# Remove lockfile if present
rm /home/opam/.mina-config/.mina-lock || true

mkdir -p /home/opam/libp2p-keys/
# Pre-generated random password for this quick test
export MINA_LIBP2P_PASS=eithohShieshichoh8uaJ5iefo1reiRudaekohG7AeCeib4XuneDet2uGhu7lahf
mina libp2p generate-keypair --privkey-path /home/opam/libp2p-keys/key
chmod -R 0700 /home/opam/libp2p-keys/

start_daemon_and_wait_for_sync() {
    mina daemon \
      --peer-list-url "$PEER_LIST_URL" \
      --libp2p-keypair "/home/opam/libp2p-keys/key" \
    &
    DAEMON_PID="$!"

    local deadline
    deadline=$(date -d "+$SYNC_TIMEOUT" +%s)

    local sync_status=""
    while [ "$(date +%s)" -lt $deadline ]; do
        sync_status=$(timeout 5 mina-graphql-client sync-status \
            --graphql-uri http://localhost:3085/graphql --raw \
            2>/dev/null || echo "CONNECT_ERROR")
        if [[ "$sync_status" == "Synced" ]]; then
            break
        fi
        sleep "$WAIT_BETWEEN_POLLING_GRAPHQL"
    done

    if [[ "$sync_status" != "Synced" ]]; then
        echo "Error: Daemon failed to sync into network within timeout of $SYNC_TIMEOUT, current status: $sync_status"
        exit 1
    fi

    NETWORK_ID=$(timeout 10 mina-graphql-client network-id \
        --graphql-uri http://localhost:3085/graphql --raw)
    EXPECTED_NETWORK="mina:$NETWORK_NAME"

    if [[ "$NETWORK_ID" == "$EXPECTED_NETWORK" ]]; then
        echo "Network id correct ($NETWORK_ID)"
    else
        echo "Network id incorrect (expected: $EXPECTED_NETWORK, got: $NETWORK_ID)"
        exit 1
    fi
}

start_daemon_and_wait_for_sync
mina client stop-daemon
wait "$DAEMON_PID"

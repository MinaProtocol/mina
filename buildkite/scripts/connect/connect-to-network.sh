#!/bin/bash

set -eox pipefail

# Connect test: start the daemon, sync against the live network and assert the
# network id, then exercise the RocksDB storage migration -- convert the store to
# the legacy format, downgrade to the official stable release, confirm the old
# daemon still syncs the converted store, upgrade back and re-sync.
#
# Binary acquisition is split from the migration: the CURRENT-version binaries
# (mina, the current rocksdb-scanner, the in-repo storage converter,
# mina-graphql-client, libp2p_helper) are restored bare from the apps cache --
# mirroring what their .debs install -- with a .deb fallback on a cache miss. The
# RELEASED bits the downgrade needs (the stable 3.3.0 recovery storage toolbox
# and the official 3.3.0 daemon) are not built here, so they stay .deb installs.

# --- Initialization ---
MINA_DEBIAN_NETWORK=""
NETWORK_NAME=""
WAIT_BETWEEN_POLLING_GRAPHQL=""
SYNC_TIMEOUT=""
STABLE_VERSION="3.3.0"

# Must match build_daemon_storage_toolbox_deb in scripts/debian/builder-helpers.sh.
ROCKSDB_VERSION="10.5.2"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

All arguments are mandatory unless noted:
  --mina-debian-network <val>        Mina debian network name
  --network-name <val>               Testnet name (used for seeds URL and validation)
  --wait-between-polling <val>       Duration to wait between GraphQL polling
  --sync-timeout <val>               Duration to wait before considering the sync is failed
  --peer-list-url <val>              Peer list URL
  --stable-version <val>             Stable release to downgrade to (default: ${STABLE_VERSION})
  --help                             Display this help message

Example:
  $0 --mina-debian-network devnet --network-name devnet --wait-between-polling 10s --sync-timeout 20min
EOF
    exit 1
}

# --- Long-Flag Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mina-debian-network) MINA_DEBIAN_NETWORK="$2"; shift 2 ;;
        --network-name) NETWORK_NAME="$2"; shift 2 ;;
        --peer-list-url) PEER_LIST_URL="$2"; shift 2 ;;
        --wait-between-polling) WAIT_BETWEEN_POLLING_GRAPHQL="$2"; shift 2 ;;
        --sync-timeout) SYNC_TIMEOUT="$2"; shift 2 ;;
        --stable-version) STABLE_VERSION="$2"; shift 2 ;;
        --help) usage ;;
        *) echo "Error: Unknown argument '$1'"; usage ;;
    esac
done

# --- Validation ---
if [[ -z "$MINA_DEBIAN_NETWORK" || -z "$NETWORK_NAME" || -z "$WAIT_BETWEEN_POLLING_GRAPHQL" || -z "$SYNC_TIMEOUT" || -z "$PEER_LIST_URL" ]]; then
    echo "Error: All required arguments must be provided."
    usage
fi

# --- Main Script Logic ---

git config --global --add safe.directory /workdir
source buildkite/scripts/debian/update.sh --verbose
source buildkite/scripts/export-git-env-vars.sh

SUDO=""
if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

# Where the current rocksdb-scanner lives -- the same versioned path the
# mina-daemon-storage-toolbox .deb installs it to, so mina-storage-converter
# finds it identically.
CURRENT_SCANNER_DIR="/usr/lib/mina/storage/${ROCKSDB_VERSION}/${GITTAG}"

# restore_current_mina re-installs the current daemon (used initially and again
# when upgrading back after the downgrade), preferring the apps cache.
BARE=0
restore_current_mina() {
  if [[ "$BARE" == "1" ]]; then
    ./buildkite/scripts/apps/restore_binary.sh "$MINA_DEBIAN_NETWORK"
  else
    source buildkite/scripts/debian/install.sh "mina-${MINA_DEBIAN_NETWORK}" 1
  fi
}

# Restore the current-version binaries bare from the apps cache (mirroring the
# .debs); fall back to the .debs on any cache miss.
if ./buildkite/scripts/apps/restore_binary.sh "$MINA_DEBIAN_NETWORK" \
  && ./buildkite/scripts/apps/restore_app.sh "$MINA_DEBIAN_NETWORK" mina_graphql_client_app.exe mina-graphql-client \
  && ./buildkite/scripts/apps/restore_app.sh "$MINA_DEBIAN_NETWORK" libp2p_helper coda-libp2p_helper \
  && MINA_BIN_DIR="$CURRENT_SCANNER_DIR" ./buildkite/scripts/apps/restore_app.sh "$MINA_DEBIAN_NETWORK" rocksdb_scanner.exe mina-rocksdb-scanner \
  && ./buildkite/scripts/apps/restore_daemon_config.sh "$MINA_DEBIAN_NETWORK"; then
  BARE=1
  # The converter is an in-repo script (the .deb just packages it); install it
  # the same way the .deb does.
  $SUDO install -D -m 0755 scripts/rocksdb/convert-to-legacy.sh /usr/local/bin/mina-storage-converter
  # The recovery storage toolbox .deb installed below has a dpkg dependency on
  # the mina-logproc .deb. The .deb fallback path pulls it in transitively via
  # mina-<net>; in the bare path nothing does, and a bare binary can't satisfy a
  # dpkg Depends, so install the current mina-logproc .deb explicitly. (Only the
  # current build root ships mina-logproc -- the legacy root does not.)
  source buildkite/scripts/debian/install.sh "mina-logproc" 1
  echo "Using bare mina + current rocksdb-scanner + storage-converter from apps cache"
else
  echo "Falling back to debian-installed mina-${MINA_DEBIAN_NETWORK} + storage toolbox"
  source buildkite/scripts/debian/install.sh "mina-${MINA_DEBIAN_NETWORK},mina-daemon-storage-toolbox" 1
fi

# The stable (3.3.0) recovery storage toolbox ships the legacy scanner at its own
# versioned path; it is a released artifact, not built here, so it stays a .deb.
FORCE_VERSION="*" ROOT="legacy" ./buildkite/scripts/debian/install.sh "mina-daemon-recovery-storage-toolbox" 1

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
        if [[ "$sync_status" == "SYNCED" ]]; then
            break
        fi
        sleep "$WAIT_BETWEEN_POLLING_GRAPHQL"
    done

    if [[ "$sync_status" != "SYNCED" ]]; then
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

# --- Step 1: sync with current mina ---
start_daemon_and_wait_for_sync

# --- Step 2: stop daemon ---
mina client stop-daemon
wait "$DAEMON_PID"

# --- Step 3: convert RocksDB to the legacy format ---
mina-storage-converter \
    --node-dir /home/opam/.mina-config \
    --current-scanner "${CURRENT_SCANNER_DIR}/mina-rocksdb-scanner" \
    --stable-scanner "/usr/lib/mina/storage/5.7.12/${STABLE_VERSION}/mina-rocksdb-scanner" \
    --yes --verbose

# --- Downgrade to the official stable release ---
if [[ "$MINA_DEBIAN_NETWORK" == "mainnet" ]]; then
    source buildkite/scripts/debian/install_official.sh --package "mina-mainnet" --channel stable --version "$STABLE_VERSION*"
else
    source buildkite/scripts/debian/install_official.sh --package "mina-${MINA_DEBIAN_NETWORK}" --version "$STABLE_VERSION*"
fi

# --- Step 4: sync with legacy mina and shut down ---
start_daemon_and_wait_for_sync
mina client stop-daemon
wait "$DAEMON_PID"

# --- Step 5: upgrade mina back to current ---
restore_current_mina

# --- Step 6: sync with current mina ---
start_daemon_and_wait_for_sync

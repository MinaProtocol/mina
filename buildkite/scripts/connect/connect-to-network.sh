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

start_daemon_and_wait_for_sync() {
    local MINA="$1"

    # Start the daemon in the background
    "$MINA" daemon \
      --peer-list-url "https://storage.googleapis.com/seed-lists/${NETWORK_NAME}_seeds.txt" \
      --libp2p-keypair "/home/opam/libp2p-keys/key" \
    &

    DAEMON_PID="$!"

    # Attempt to connect to the GraphQL client every X seconds for 24 retries
    num_status_retries=24
    for ((i=1;i<=$num_status_retries;i++)); do
        sleep "$WAIT_BETWEEN_POLLING_GRAPHQL"
        set +e
        "$MINA" client status
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
    "$MINA" client status

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
}

start_daemon_and_wait_for_sync mina

# prepare rocksdb scanner build on "master"
# TODO: after this is released, install from debian directly.
git fetch origin 
git checkout origin/lyh/rocksdb-scanner-master

# It doesn't matter what profile we're using.
export DUNE_PROFILE="$NETWORK_NAME"
dune build src/app/rocksdb-scanner/rocksdb_scanner.exe
dune build src/app/cli/src/mina.exe
ROCKSDB_SCANNER_MASTER="_build/default/src/app/rocksdb-scanner/rocksdb_scanner.exe"
MINA_MASTER="_build/default/src/app/cli/src/mina.exe"

git checkout -

is_rocksdb() {
    local dir="$1"

    # 1. Check if the path is a valid directory
    if [[ ! -d "$dir" ]]; then
        echo "Error: '$dir' is not a directory."
        return 1
    fi

    # 2. Check for the RocksDB files
    # - CURRENT: Points to the current manifest
    # - MANIFEST-*: The database ledger
    local has_current=$(ls "$dir"/CURRENT 2>/dev/null)
    local has_manifest=$(ls "$dir"/MANIFEST-* 2>/dev/null | head -n 1)

    if [[ -n "$has_current" && -n "$has_manifest" ]]; then
        echo "Valid RocksDB instance found in: $dir"
        return 0
    else
        return 1
    fi
}

list_rocksdb_instances() {
    local search_path="$1"

    if [[ ! -d "$search_path" ]]; then
        echo "Error: $search_path is not a directory." >&2
        return 1
    fi

    # Use 'find' to locate all 'CURRENT' files, then validate their parent directory
    find "$search_path" -type f -name "CURRENT" 2>/dev/null | while read -r current_file; do
        local parent_dir
        parent_dir=$(dirname "$current_file")
        
        # Reuse the validation function
        if is_rocksdb "$parent_dir"; then
            echo "$parent_dir"
        fi
    done
}

downgrade_db(){
    local db_path="$1"
    mina-rocksdb-scanner dump --db-path "$db_path" --output-file "$db_path/scanner_dump.txt"
    echo "Successfully dumped DB at $db_path"
    "$ROCKSDB_SCANNER_MASTER" restore --db-path "$db_path" --input-file "$db_path/scanner_dump.txt"
    echo "Successfully downgraded DB at $db_path"
}

# Wait for daemon to shutdown
"$MINA_EXE" client stop-daemon --daemon-port "$port"
wait "$DAEMON_PID"

NODE_DIR="~/.mina-config"

mapfile -t db_list < <(list_rocksdb_instances "$MINA_CONFIG")

# Iterate through found instances and apply dump_db
echo "Searching for RocksDB instances in $NODE_DIR..."
for db_path in "${db_list[@]}"; do
    echo "------------------------------------------------"
    
    if [[ -f "$db_path/LOCK" ]]; then
        echo "Warning: $db_path appears to be in use (LOCK file present)."
    fi

    downgrade_db "$db_path"
done

# Test with master mina
start_daemon_and_wait_for_sync "$MINA_MASTER"

#!/usr/bin/env bash

usage() {
    echo "Usage: $0 --node-dir <PATH> --current-scanner <PATH> --stable-scanner <PATH>"
    echo ""
    echo "Required Arguments:"
    echo "  --node-dir          Path to the node configuration directory"
    echo "  --current-scanner   Path to the current RocksDB scanner binary"
    echo "  --stable-scanner    Path to the stable scanner binary (target version)"
    exit 1
}

is_rocksdb() {
    local dir="$1"

    # 1. Check if the path is a valid directory
    if [[ ! -d "$dir" ]]; then
        echo "Error: '$dir' is not a directory." >&2
        return 1
    fi

    # 2. Check for the RocksDB files
    # - CURRENT: Points to the current manifest
    # - MANIFEST-*: The database ledger
    local has_current
    has_current=$(ls "$dir"/CURRENT 2>/dev/null)
    local has_manifest
    has_manifest=$(ls "$dir"/MANIFEST-* 2>/dev/null | head -n 1)

    if [[ -n "$has_current" && -n "$has_manifest" ]]; then
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
    local current_bin="$2"
    local stable_bin="$3"
    local dump_file="${db_path}_dump.txt"

    # Execute Dump
    if "$current_bin" dump --db-path "$db_path" --output-file "$dump_file"; then
        echo "Successfully dumped DB at $db_path"
    else
        echo "Error: Failed to dump DB at $db_path" >&2
        return 1
    fi

    rm -rf "${db_path}"

    # Execute Restore/Downgrade
    if "$stable_bin" restore --db-path "$db_path" --input-file "$dump_file"; then
        echo "Successfully downgraded DB at $db_path"
        # Cleanup dump file after successful restore
        rm "$dump_file"
    else
        echo "Error: Failed to restore DB at $db_path" >&2
        return 1
    fi
}

# --- Argument Parsing (Long-form) ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        --node-dir)
            NODE_DIR="$2"
            shift 2
            ;;
        --current-scanner)
            CURRENT_ROCKSDB_SCANNER="$2"
            shift 2
            ;;
        --stable-scanner)
            STABLE_SCANNER="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
done

if [[ -z "$NODE_DIR" || -z "$CURRENT_ROCKSDB_SCANNER" || -z "$STABLE_SCANNER" ]]; then
    echo "Error: All arguments (--node-dir, --current-scanner, --stable-scanner) are required."
    usage
fi

# Expand tilde in NODE_DIR
NODE_DIR="${NODE_DIR/#\~/$HOME}"

# Verify binaries exist and are executable
for bin in "$CURRENT_ROCKSDB_SCANNER" "$STABLE_SCANNER"; do
    if [[ ! -x "$bin" ]]; then
        echo "Error: Binary not found or not executable: $bin"
        exit 1
    fi
done

echo "Searching for RocksDB instances in $NODE_DIR..."

mapfile -t db_list < <(list_rocksdb_instances "$NODE_DIR")

for db_path in "${db_list[@]}"; do
    echo "------------------------------------------------"
    echo "Processing: ${db_path}"
    
    downgrade_db "$db_path" "$CURRENT_ROCKSDB_SCANNER" "$STABLE_SCANNER"
done

echo "Process complete."

#!/usr/bin/env bash

# RocksDB Legacy Converter
#
# Converts all RocksDB instances in a Mina node directory from a newer RocksDB
# version to a stable/legacy version. For each RocksDB instance found under
# the node directory, the script:
#   1. Dumps the database using the current (newer) scanner binary
#   2. Backs up the original database directory (mv, not rm)
#   3. Restores from the dump using the stable (legacy) scanner binary
#   4. Removes the backup only after successful restore
#
# This is needed when downgrading RocksDB format compatibility after a Mina
# node version change, or when migrating data between incompatible RocksDB
# versions.
#
# Note: The dump+backup approach temporarily requires roughly 2x the disk
# space of the original database. Use --backup-dir to place backups on a
# separate filesystem if needed.
#
# Exit codes:
#   0 - All databases converted successfully (or none found)
#   1 - One or more databases failed to convert
#   2 - Argument or validation error
#
# Environment variable defaults (overridable via command-line arguments):
#   NODE_DIR        - Path to the Mina node configuration directory

set -euo pipefail

# --- Default configuration ---
CURRENT_SCANNER="/usr/lib/mina/storage/10.5.2/3.3.0/mina-rocksdb-scanner"
STABLE_SCANNER="/usr/lib/mina/storage/5.7.12/3.3.0/mina-rocksdb-scanner"
NODE_DIR="${NODE_DIR:-~/.mina-config}"

# --- Flag defaults ---
DRY_RUN=false
VERBOSE=false
YES=false
BACKUP_DIR=""

# --- Logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "[DEBUG] $*"
    fi
}

# --- Usage ---
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Converts all RocksDB instances in a Mina node directory from a newer version
to a stable/legacy version using dump and restore.

Required Arguments:
  --node-dir PATH          Path to the node configuration directory
  --current-scanner PATH   Path to the current (newer) RocksDB scanner binary
  --stable-scanner PATH    Path to the stable (legacy) scanner binary

Optional Arguments:
  --backup-dir PATH        Directory to store database backups and dumps
                           (default: alongside original DB as <db_path>.bak)
  --dry-run                List what would be done without making changes
  --yes, -y                Skip confirmation prompt (for CI/automation)
  --verbose, -v            Show detailed output during operations
  --help, -h               Show this help message

Environment Variable Defaults:
  NODE_DIR=${NODE_DIR}

Examples:
  # Local development (uses env var defaults for scanners)
  $0 --node-dir ~/.mina-config \\
     --current-scanner /usr/lib/mina/10.5.2/3.3.0/mina-rocksdb-scanner \\
     --stable-scanner /usr/lib/mina/5.7.12/3.3.0/mina-rocksdb-scanner

  # Production use with auto-confirm (CI/automation)
  $0 --node-dir /var/lib/mina --yes \\
     --current-scanner /usr/lib/mina/10.5.2/3.3.0/mina-rocksdb-scanner \\
     --stable-scanner /usr/lib/mina/5.7.12/3.3.0/mina-rocksdb-scanner

  # Dry run to preview what would happen
  $0 --node-dir ~/.mina-config --dry-run

  # With explicit backup directory (useful when disk space is tight)
  $0 --node-dir /var/lib/mina --backup-dir /tmp/rocksdb-backups \\
     --current-scanner /usr/lib/mina/10.5.2/3.3.0/mina-rocksdb-scanner \\
     --stable-scanner /usr/lib/mina/5.7.12/3.3.0/mina-rocksdb-scanner
EOF
    exit "${1:-2}"
}

# --- Utility Functions ---

is_rocksdb() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        log_verbose "'$dir' is not a directory, skipping"
        return 1
    fi

    # Check for RocksDB signature files:
    # - CURRENT: Points to the current manifest
    # - MANIFEST-*: The database manifest/ledger
    if [[ -f "$dir/CURRENT" ]] && compgen -G "$dir/MANIFEST-*" > /dev/null; then
        return 0
    else
        return 1
    fi
}

list_rocksdb_instances() {
    local search_path="$1"

    if [[ ! -d "$search_path" ]]; then
        log_error "$search_path is not a directory."
        return 1
    fi

    # Use 'find' to locate all 'CURRENT' files, then validate their parent directory
    find "$search_path" -type f -name "CURRENT" 2>/dev/null | while read -r current_file; do
        local parent_dir
        parent_dir=$(dirname "$current_file")

        if is_rocksdb "$parent_dir"; then
            echo "$parent_dir"
        fi
    done
}

downgrade_db() {
    local db_path="$1"
    local current_bin="$2"
    local stable_bin="$3"

    # Compute a collision-safe name for backup/dump files
    local relative_path="${db_path#"$NODE_DIR"/}"
    local safe_name="${relative_path//\//_}"

    # Determine backup and dump file locations
    local backup_path
    local dump_file
    if [[ -n "$BACKUP_DIR" ]]; then
        backup_path="${BACKUP_DIR}/${safe_name}.bak"
        dump_file="${BACKUP_DIR}/${safe_name}_dump.txt"
    else
        backup_path="${db_path}.bak"
        dump_file="${db_path}_dump.txt"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would dump:    $db_path -> $dump_file"
        log_info "[DRY RUN] Would backup:  $db_path -> $backup_path"
        log_info "[DRY RUN] Would restore: $dump_file -> $db_path"
        return 0
    fi

    # Step 1: Dump with current scanner
    log_info "Dumping DB: $db_path -> $dump_file"
    if "$current_bin" dump --db-path "$db_path" --output-file "$dump_file"; then
        log_info "Successfully dumped DB at $db_path"
    else
        log_error "Failed to dump DB at $db_path"
        return 1
    fi

    # Step 2: Back up original DB (move, not delete)
    log_info "Backing up DB: $db_path -> $backup_path"
    if [[ -d "$backup_path" ]]; then
        log_warn "Removing stale backup at $backup_path"
        rm -rf "$backup_path"
    fi
    mv "$db_path" "$backup_path"

    # Step 3: Restore with stable scanner
    log_info "Restoring DB: $dump_file -> $db_path"
    if "$stable_bin" restore --db-path "$db_path" --input-file "$dump_file"; then
        log_info "Successfully downgraded DB at $db_path"
        # Step 4: Clean up backup and dump only on success
        log_verbose "Removing backup: $backup_path"
        rm -rf "$backup_path"
        log_verbose "Removing dump file: $dump_file"
        rm -f "$dump_file"
    else
        log_error "Failed to restore DB at $db_path"
        log_warn "Restoring original DB from backup..."
        rm -rf "$db_path" 2>/dev/null || true
        mv "$backup_path" "$db_path"
        log_warn "Original DB restored. Dump file preserved at: $dump_file"
        return 1
    fi
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --node-dir)
            NODE_DIR="$2"
            shift 2
            ;;
        --current-scanner)
            CURRENT_SCANNER="$2"
            shift 2
            ;;
        --stable-scanner)
            STABLE_SCANNER="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --yes|-y)
            YES=true
            shift
            ;;
        --help|-h)
            usage 0
            ;;
        *)
            log_error "Unknown argument: $1"
            usage 2
            ;;
    esac
done

# --- Validate required arguments ---
if [[ -z "${NODE_DIR:-}" || -z "${CURRENT_SCANNER:-}" || -z "${STABLE_SCANNER:-}" ]]; then
    log_error "All arguments (--node-dir, --current-scanner, --stable-scanner) are required."
    usage 2
fi

# --- Expand tilde in all paths ---
NODE_DIR="${NODE_DIR/#\~/$HOME}"
CURRENT_SCANNER="${CURRENT_SCANNER/#\~/$HOME}"
STABLE_SCANNER="${STABLE_SCANNER/#\~/$HOME}"
if [[ -n "$BACKUP_DIR" ]]; then
    BACKUP_DIR="${BACKUP_DIR/#\~/$HOME}"
fi

# --- Verify node directory exists ---
if [[ ! -d "$NODE_DIR" ]]; then
    log_error "Node directory does not exist: $NODE_DIR"
    exit 2
fi

# --- Verify binaries exist and are executable ---
for bin in "$CURRENT_SCANNER" "$STABLE_SCANNER"; do
    if [[ ! -x "$bin" ]]; then
        log_error "Binary not found or not executable: $bin"
        exit 2
    fi
done

# --- Verify/create backup directory ---
if [[ -n "$BACKUP_DIR" ]]; then
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_info "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
fi

# --- Cleanup trap ---
CURRENT_DB_PATH=""
# shellcheck disable=SC2329
cleanup() {
    if [[ -n "$CURRENT_DB_PATH" ]]; then
        log_warn "Interrupted while processing: $CURRENT_DB_PATH"
        log_warn "The database may be in an inconsistent state."
        log_warn "Check for backup at: ${CURRENT_DB_PATH}.bak"
    fi
}
trap cleanup INT TERM

# --- Discovery ---
log_info "Searching for RocksDB instances in $NODE_DIR..."
log_verbose "Current scanner: $CURRENT_SCANNER"
log_verbose "Stable scanner:  $STABLE_SCANNER"

mapfile -t db_list < <(list_rocksdb_instances "$NODE_DIR")

if [[ ${#db_list[@]} -eq 0 ]]; then
    log_warn "No RocksDB instances found in $NODE_DIR"
    exit 0
fi

log_info "Found ${#db_list[@]} RocksDB instance(s):"
for db_path in "${db_list[@]}"; do
    log_info "  - $db_path"
done
echo ""

# --- Confirmation prompt ---
if [[ "$DRY_RUN" == false && "$YES" == false ]]; then
    echo "This will dump, backup, and restore ${#db_list[@]} database(s)."
    read -r -p "Continue? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Aborted by user."
        exit 0
    fi
fi

# --- Processing ---
count_total=${#db_list[@]}
count_success=0
count_failed=0

for db_path in "${db_list[@]}"; do
    echo "------------------------------------------------"
    log_info "Processing: ${db_path} [$((count_success + count_failed + 1))/${count_total}]"
    CURRENT_DB_PATH="$db_path"

    if downgrade_db "$db_path" "$CURRENT_SCANNER" "$STABLE_SCANNER"; then
        count_success=$((count_success + 1))
    else
        count_failed=$((count_failed + 1))
        log_error "Failed to process: $db_path (continuing with remaining databases)"
    fi
done

CURRENT_DB_PATH=""

# --- Summary ---
echo ""
echo "================================================"
log_info "Summary:"
log_info "  Total databases found: $count_total"
log_info "  Succeeded: $count_success"
if [[ $count_failed -gt 0 ]]; then
    log_error "  Failed:    $count_failed"
fi
echo "================================================"

if [[ $count_failed -gt 0 ]]; then
    exit 1
fi

exit 0

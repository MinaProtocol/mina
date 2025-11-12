#!/usr/bin/env bash

set -euo pipefail

# Script to test block race condition with real mainnet archive data
# Sets up postgres database, imports dump, and runs the test

# Default values
PORT_BASE=17000
POSTGRES_PORT=15000
NUM_BLOCKS=3
NUM_ZKAPP_TXS=10
NUM_PAYMENTS=110

# Data URLs
ARCHIVE_DUMP_URL="https://storage.googleapis.com/mina-archive-dumps/mainnet-archive-dump-2025-11-11_0000.sql.tar.gz"
LEDGER_URL="https://storage.googleapis.com/o1labs-ci-test-data/ledgers/single-bp-ledger.tar"

# Local paths
DUMP_ARCHIVE="mainnet-archive-dump-2025-11-11_0000.sql.tar.gz"
DUMP_SQL="mainnet-archive-dump-2025-11-11_0000.sql"
LEDGER_ARCHIVE="single-bp-ledger.tar"
DB_DIR="db"
LEDGER_DIR="ledger"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Required parameters:
  --mina-exe PATH              Path to mina executable
  --archive-exe PATH           Path to archive executable
  --rosetta-exe PATH           Path to rosetta executable

Optional parameters:
  --postgres-port PORT         PostgreSQL server port (default: $POSTGRES_PORT)
  --port-base PORT             Base port number for services (default: $PORT_BASE)
  --num-blocks N               Number of blocks to generate (default: $NUM_BLOCKS)
  --num-zkapp-txs N            Number of zkApp transactions (default: $NUM_ZKAPP_TXS)
  --num-payments N             Number of payment transactions (default: $NUM_PAYMENTS)
  -h, --help                   Display this help message

Example:
  $0 --mina-exe ./mina.exe --archive-exe ./archive.exe --rosetta-exe ./rosetta.exe
EOF
    exit 1
}

# Parse command line arguments
MINA_EXE=""
ARCHIVE_EXE=""
ROSETTA_EXE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --postgres-port)
            POSTGRES_PORT="$2"
            shift 2
            ;;
        --port-base)
            PORT_BASE="$2"
            shift 2
            ;;
        --num-blocks)
            NUM_BLOCKS="$2"
            shift 2
            ;;
        --num-zkapp-txs)
            NUM_ZKAPP_TXS="$2"
            shift 2
            ;;
        --num-payments)
            NUM_PAYMENTS="$2"
            shift 2
            ;;
        --mina-exe)
            MINA_EXE="$2"
            shift 2
            ;;
        --archive-exe)
            ARCHIVE_EXE="$2"
            shift 2
            ;;
        --rosetta-exe)
            ROSETTA_EXE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [[ -z "$MINA_EXE" ]]; then
    echo "Error: --mina-exe is required"
    usage
fi

if [[ -z "$ARCHIVE_EXE" ]]; then
    echo "Error: --archive-exe is required"
    usage
fi

if [[ -z "$ROSETTA_EXE" ]]; then
    echo "Error: --rosetta-exe is required"
    usage
fi

# Check for required dependencies
echo "Checking for required dependencies..."
MISSING_DEPS=()

for cmd in curl tar python3 jq initdb postgres createdb psql; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo "Error: Missing required dependencies: ${MISSING_DEPS[*]}"
    echo "Please install the missing tools and try again."
    echo ""
    # Map command names to nix package names
    NIX_PACKAGES=()
    NEED_POSTGRESQL=false
    for dep in "${MISSING_DEPS[@]}"; do
        case "$dep" in
            curl) NIX_PACKAGES+=("curl") ;;
            tar) NIX_PACKAGES+=("gnutar") ;;
            python3) NIX_PACKAGES+=("python3") ;;
            jq) NIX_PACKAGES+=("jq") ;;
            initdb|postgres|createdb|psql)
                if [[ "$NEED_POSTGRESQL" == "false" ]]; then
                    NIX_PACKAGES+=("postgresql" "glibcLocales")
                    NEED_POSTGRESQL=true
                fi
                ;;
        esac
    done
    if [[ ${#NIX_PACKAGES[@]} -gt 0 ]]; then
        echo "On NixOS, you can run:"
        echo "  nix-shell -p ${NIX_PACKAGES[*]}"
    fi
    exit 1
fi
echo "All dependencies found"
echo ""

# Validate executables
if [[ ! -x "$MINA_EXE" ]]; then
    echo "Error: Mina executable not found or not executable: $MINA_EXE"
    exit 1
fi

if [[ ! -x "$ARCHIVE_EXE" ]]; then
    echo "Error: Archive executable not found or not executable: $ARCHIVE_EXE"
    exit 1
fi

if [[ ! -x "$ROSETTA_EXE" ]]; then
    echo "Error: Rosetta executable not found or not executable: $ROSETTA_EXE"
    exit 1
fi

# Get current username for postgres URI
CURRENT_USER=$(whoami)
POSTGRES_URI="postgres://$CURRENT_USER@localhost:$POSTGRES_PORT/archive"

# PID for postgres cleanup
POSTGRES_PID=""

# Cleanup function
cleanup() {
    echo "Cleaning up postgres server..."
    if [[ -n "$POSTGRES_PID" ]] && kill -0 "$POSTGRES_PID" 2>/dev/null; then
        echo "Stopping PostgreSQL (PID: $POSTGRES_PID)"
        kill "$POSTGRES_PID" 2>/dev/null || true
        wait "$POSTGRES_PID" 2>/dev/null || true
    fi
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

echo "=========================================="
echo "Mina Rosetta Block Race Test (with data)"
echo "=========================================="
echo "Configuration:"
echo "  PostgreSQL port:  $POSTGRES_PORT"
echo "  Port base:        $PORT_BASE"
echo "  Blocks:           $NUM_BLOCKS"
echo "  ZkApp txs:        $NUM_ZKAPP_TXS"
echo "  Payments:         $NUM_PAYMENTS"
echo "  User:             $CURRENT_USER"
echo "=========================================="
echo ""

# Step 1: Download and extract archive dump
echo "[1/5] Downloading and extracting archive dump..."
if [[ -f "$DUMP_SQL" ]]; then
    echo "  SQL dump already exists, skipping download"
else
    if [[ ! -f "$DUMP_ARCHIVE" ]]; then
        echo "  Downloading $ARCHIVE_DUMP_URL..."
        curl -L -o "$DUMP_ARCHIVE" "$ARCHIVE_DUMP_URL"
    else
        echo "  Archive file already exists, skipping download"
    fi
    
    echo "  Extracting archive dump..."
    tar -xzf "$DUMP_ARCHIVE"
fi
echo "  Archive dump ready"
echo ""

# Step 2: Download ledger data
echo "[2/5] Downloading ledger data..."
if [[ ! -f "$LEDGER_ARCHIVE" ]]; then
    echo "  Downloading $LEDGER_URL..."
    curl -L -o "$LEDGER_ARCHIVE" "$LEDGER_URL"
else
    echo "  Ledger archive already exists, skipping download"
fi
echo "  Ledger archive ready"
echo ""

# Step 3: Setup postgres database
echo "[3/5] Setting up PostgreSQL database..."
if [[ -d "$DB_DIR" ]]; then
    echo "  Removing existing database directory..."
    rm -rf "$DB_DIR"
fi

echo "  Creating database directory..."
mkdir -p "$DB_DIR"
DB_DIR_ABS=$(realpath "$DB_DIR")

echo "  Initializing database..."
initdb "$DB_DIR_ABS"

echo "  Starting PostgreSQL server..."
postgres -D "$DB_DIR_ABS" -k "$DB_DIR_ABS" -p "$POSTGRES_PORT" &
POSTGRES_PID=$!
echo "  PostgreSQL started (PID: $POSTGRES_PID)"

echo "  Waiting for PostgreSQL to be ready..."
sleep 5

# Create the archive database
echo "  Creating 'archive' database..."
createdb -h "$DB_DIR_ABS" -p "$POSTGRES_PORT" archive || true

# Import the dump
echo "  Importing SQL dump (this may take a while)..."
psql -h "$DB_DIR_ABS" -p "$POSTGRES_PORT" -d archive -f "$DUMP_SQL" > /dev/null 2>&1

echo "  Database setup complete"
echo ""

# Step 4: Setup ledger
echo "[4/5] Setting up ledger..."
if [[ -d "$LEDGER_DIR" ]]; then
    echo "  Removing existing ledger directory..."
    rm -rf "$LEDGER_DIR"
fi

echo "  Creating ledger directory..."
mkdir -p "$LEDGER_DIR"
chmod 700 "$LEDGER_DIR"

echo "  Extracting ledger archive..."
tar -xf "$LEDGER_ARCHIVE" -C "$LEDGER_DIR"

echo "  Ledger setup complete"
echo ""

# Step 5: Run the test
echo "[5/5] Running block race test..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/test-block-race.sh" \
    --ledger "$LEDGER_DIR" \
    --postgres-uri "$POSTGRES_URI" \
    --port-base "$PORT_BASE" \
    --num-blocks "$NUM_BLOCKS" \
    --num-zkapp-txs "$NUM_ZKAPP_TXS" \
    --num-payments "$NUM_PAYMENTS" \
    --mina-exe "$MINA_EXE" \
    --archive-exe "$ARCHIVE_EXE" \
    --rosetta-exe "$ROSETTA_EXE"

TEST_RESULT=$?

echo ""
echo "=========================================="
if [[ $TEST_RESULT -eq 0 ]]; then
    echo "OVERALL TEST PASSED"
else
    echo "OVERALL TEST FAILED (exit code: $TEST_RESULT)"
fi
echo "=========================================="

exit $TEST_RESULT

#!/usr/bin/env bash

set -euo pipefail

# Script to test block race condition between Archive and Rosetta services
# Tests for account_creation_fee_via_payment operations appearing and disappearing

# Default values
PORT_BASE=17000
NUM_BLOCKS=3
NUM_ZKAPP_TXS=10
NUM_PAYMENTS=110

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Required parameters:
  --ledger DIR                  Directory containing ledger files
  --mina-exe PATH              Path to mina executable
  --archive-exe PATH           Path to archive executable
  --rosetta-exe PATH           Path to rosetta executable

Optional parameters:
  --postgres-uri URI           PostgreSQL connection URI
  --port-base PORT             Base port number (default: $PORT_BASE)
  --num-blocks N               Number of blocks to generate (default: $NUM_BLOCKS)
  --num-zkapp-txs N            Number of zkApp transactions (default: $NUM_ZKAPP_TXS)
  --num-payments N             Number of payment transactions (default: $NUM_PAYMENTS)
  -h, --help                   Display this help message

Example:
  $0 --ledger ./ledger --mina-exe ./mina.exe --archive-exe ./archive.exe --rosetta-exe ./rosetta.exe
EOF
    exit 1
}

# Parse command line arguments
LEDGER_DIR=""
MINA_EXE=""
ARCHIVE_EXE=""
ROSETTA_EXE=""
POSTGRES_URI=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --ledger)
            LEDGER_DIR="$2"
            shift 2
            ;;
        --postgres-uri)
            POSTGRES_URI="$2"
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
if [[ -z "$LEDGER_DIR" ]]; then
    echo "Error: --ledger is required"
    usage
fi

if [[ -z "$POSTGRES_URI" ]]; then
    echo "Error: --postgres-uri is required"
    usage
fi

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

for cmd in python3 curl jq; do
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
    for dep in "${MISSING_DEPS[@]}"; do
        case "$dep" in
            python3) NIX_PACKAGES+=("python3") ;;
            curl) NIX_PACKAGES+=("curl") ;;
            jq) NIX_PACKAGES+=("jq") ;;
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

# Validate that paths exist
if [[ ! -d "$LEDGER_DIR" ]]; then
    echo "Error: Ledger directory does not exist: $LEDGER_DIR"
    exit 1
fi

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

# Calculate ports
ARCHIVE_PORT=$((PORT_BASE + 1))
GRAPHQL_PORT=$((PORT_BASE + 2))
ROSETTA_PORT=$((PORT_BASE + 3))

# PIDs for cleanup
ARCHIVE_PID=""
ROSETTA_PID=""
GRAPHQL_MOCK_PID=""
WATCHDOG_PID=""

# Log file for watchdog
OPCOUNT_LOG="op-count.log"

# Cleanup function
cleanup() {
    echo "Cleaning up processes..."
    
    # Kill watchdog
    if [[ -n "$WATCHDOG_PID" ]] && kill -0 "$WATCHDOG_PID" 2>/dev/null; then
        echo "Stopping watchdog (PID: $WATCHDOG_PID)"
        kill "$WATCHDOG_PID" 2>/dev/null || true
    fi
    
    # Kill rosetta
    if [[ -n "$ROSETTA_PID" ]] && kill -0 "$ROSETTA_PID" 2>/dev/null; then
        echo "Stopping Rosetta (PID: $ROSETTA_PID)"
        kill "$ROSETTA_PID" 2>/dev/null || true
        wait "$ROSETTA_PID" 2>/dev/null || true
    fi
    
    # Kill GraphQL mock
    if [[ -n "$GRAPHQL_MOCK_PID" ]] && kill -0 "$GRAPHQL_MOCK_PID" 2>/dev/null; then
        echo "Stopping GraphQL mock (PID: $GRAPHQL_MOCK_PID)"
        kill "$GRAPHQL_MOCK_PID" 2>/dev/null || true
        wait "$GRAPHQL_MOCK_PID" 2>/dev/null || true
    fi
    
    # Kill archive
    if [[ -n "$ARCHIVE_PID" ]] && kill -0 "$ARCHIVE_PID" 2>/dev/null; then
        echo "Stopping Archive (PID: $ARCHIVE_PID)"
        kill "$ARCHIVE_PID" 2>/dev/null || true
        wait "$ARCHIVE_PID" 2>/dev/null || true
    fi
    
    echo "Cleanup complete"
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

echo "=========================================="
echo "Mina Rosetta Block Race Test"
echo "=========================================="
echo "Configuration:"
echo "  Ledger directory: $LEDGER_DIR"
echo "  PostgreSQL URI:   $POSTGRES_URI"
echo "  Archive port:     $ARCHIVE_PORT"
echo "  GraphQL port:     $GRAPHQL_PORT"
echo "  Rosetta port:     $ROSETTA_PORT"
echo "  Blocks:           $NUM_BLOCKS"
echo "  ZkApp txs:        $NUM_ZKAPP_TXS"
echo "  Payments:         $NUM_PAYMENTS"
echo "=========================================="
echo ""

# Start Archive
echo "[1/3] Starting Archive service..."
"$ARCHIVE_EXE" run \
    --server-port "$ARCHIVE_PORT" \
    --postgres-uri "$POSTGRES_URI" \
    --config-file "$LEDGER_DIR/runtime_config.json" \
    --skip-genesis-loading &
ARCHIVE_PID=$!
echo "Archive started (PID: $ARCHIVE_PID)"

# Start GraphQL mock server
echo "[2/3] Starting GraphQL mock server..."
python3 -c "from http.server import BaseHTTPRequestHandler, HTTPServer; import json; exec(\"class H(BaseHTTPRequestHandler):\\n  def do_POST(self):\\n    self.send_response(200)\\n    self.send_header('Content-type', 'application/json')\\n    self.end_headers()\\n    self.wfile.write(json.dumps({'data': {'networkID': 'mina:devnet'}}).encode())\\n  def log_message(self, format, *args): pass\\nHTTPServer(('', $GRAPHQL_PORT), H).serve_forever()\")" &
GRAPHQL_MOCK_PID=$!
echo "GraphQL mock started (PID: $GRAPHQL_MOCK_PID)"

# Start Rosetta
echo "[3/3] Starting Rosetta service..."
MINA_ROSETTA_MAX_DB_POOL_SIZE=64 "$ROSETTA_EXE" \
    --archive-uri "$POSTGRES_URI" \
    --graphql-uri "http://localhost:$GRAPHQL_PORT" \
    --port "$ROSETTA_PORT" --log-level error &
ROSETTA_PID=$!
echo "Rosetta started (PID: $ROSETTA_PID)"

# Wait for services to initialize
echo ""
echo "Waiting 3 minutes for services to initialize..."
sleep 180
echo "Services should be ready"
echo ""

# Start watchdog process
echo "Starting watchdog process..."
rm -f "$OPCOUNT_LOG"
(
    while true; do
        sleep 0.05s
        curl -s -d '{"network_identifier":{"blockchain":"mina","network":"devnet"},"block_identifier":{}}' \
            "http://localhost:$ROSETTA_PORT/block" 2>/dev/null | \
            jq -r '[.block.transactions[].operations[] | select(.type == "account_creation_fee_via_payment")] | length' 2>/dev/null || echo "error"
    done > "$OPCOUNT_LOG"
) &
WATCHDOG_PID=$!
echo "Watchdog started (PID: $WATCHDOG_PID)"
echo ""

# Run submit-to-archive
echo "Submitting blocks to archive..."
echo "Preparing genesis and tmp directories..."
rm -rf genesis tmp
cp -R "$LEDGER_DIR/ledgers/" genesis
mkdir -p tmp

echo "Running mina advanced test submit-to-archive..."
TMP=tmp MINA_PRIVKEY_PASS= "$MINA_EXE" advanced test submit-to-archive \
    --archive-node-port "$ARCHIVE_PORT" \
    --config-file "$LEDGER_DIR/runtime_config.json" \
    --privkey-path "$LEDGER_DIR/plain1" \
    --num-zkapp-txs "$NUM_ZKAPP_TXS" \
    --num-payments "$NUM_PAYMENTS" \
    --num-blocks "$NUM_BLOCKS"

echo "Submit-to-archive completed"
echo "Waiting 3 minutes for archive to finish processing the blocks..."
sleep 180
echo ""

# Stop watchdog
echo "Stopping watchdog..."
if [[ -n "$WATCHDOG_PID" ]] && kill -0 "$WATCHDOG_PID" 2>/dev/null; then
    kill "$WATCHDOG_PID" 2>/dev/null || true
    wait "$WATCHDOG_PID" 2>/dev/null || true
fi

# Give a moment for final writes to log
sleep 1

# Analyze results
echo "=========================================="
echo "Analyzing results..."
echo "=========================================="

if [[ ! -f "$OPCOUNT_LOG" ]]; then
    echo "ERROR: Log file $OPCOUNT_LOG not found!"
    exit 2
fi

# Count lines with exactly "0"
ZERO_COUNT=$(grep -E '^0$' "$OPCOUNT_LOG" | wc -l || echo 0)

echo "Total lines in log: $(wc -l < "$OPCOUNT_LOG")"
echo "Lines with zero operations: $ZERO_COUNT"
echo ""

if [[ "$ZERO_COUNT" -ne 0 ]]; then
    echo "=========================================="
    echo "TEST FAILED"
    echo "=========================================="
    echo "Found $ZERO_COUNT instances where account_creation_fee_via_payment"
    echo "operations disappeared (race condition detected)"
    echo ""
    echo "This indicates that Rosetta is serving incomplete data due to"
    echo "a race condition between Archive ingestion and Rosetta queries."
    exit 2
else
    echo "=========================================="
    echo "TEST SUCCEEDED"
    echo "=========================================="
    echo "No race condition detected. All queries returned consistent data."
fi

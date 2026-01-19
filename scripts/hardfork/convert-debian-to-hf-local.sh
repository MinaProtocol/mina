#!/bin/bash

# Local script to convert a mina-daemon Debian package to a hardfork package
# This script:
# 1. Downloads the latest state dump from GCS
# 2. Generates ledger tarballs from the state dump
# 3. Creates a runtime config
# 4. Converts the debian package to a hardfork package
# 5. Optionally verifies the conversion

set -euo pipefail

usage() {
        cat <<EOF
Usage: $0 [OPTIONS]

Required arguments:
    -d, --deb-file PATH         Path to input mina-daemon debian package
    -n, --network NAME          Network name (e.g., devnet, testnet, mainnet)

Optional arguments:
    -s, --state-dump PATH_OR_GCS  Path to state dump file (local file or GCS path, e.g., /path/to/state-dump.json or gs://bucket/path)
    -o, --output-dir DIR        Output directory (default: current directory)
    -w, --work-dir DIR          Working directory for temporary files (default: auto-generated)
    --skip-verification         Skip final package verification
    --keep-temp                 Keep temporary working directory after completion
    -h, --help                  Show this help message

Examples:
    # Convert using latest devnet state dump from default GCS bucket
    $0 -d mina-daemon.deb -n devnet

    # Convert using specific state dump file
    $0 -d mina-daemon.deb -n mainnet -s /path/to/state-dump.json

    # Convert using specific state dump from GCS
    $0 -d mina-daemon.deb -n testnet -s gs://bucket/path/to/state-dump.json.gz

    # Convert with custom output directory
    $0 -d mina-daemon.deb -n testnet -o /path/to/output

EOF
        exit 1
}


# Default values
OUTPUT_DIR="."
KEEP_TEMP=false
STATE_DUMP_ARG="gs://o1labs-gitops-infrastructure/devnet/"
WORKDIR=""
SKIP_VERIFY=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--deb-file)
            INPUT_DEB="$2"
            shift 2
            ;;
        -n|--network)
            NETWORK_NAME="$2"
            shift 2
            ;;
        -s|--state-dump)
            STATE_DUMP_ARG="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -w|--work-dir)
            WORKDIR="$2"
            shift 2
            ;;
        --skip-verification)
            SKIP_VERIFY=1
            shift
            ;;
        --keep-temp)
            KEEP_TEMP=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "${INPUT_DEB:-}" ]]; then
    echo "ERROR: Input debian package file is required (-d)" >&2
    usage
fi

if [[ -z "${NETWORK_NAME:-}" ]]; then
    echo "ERROR: Network name is required (-n)" >&2
    usage
fi

# Validate input debian package exists
if [[ ! -f "$INPUT_DEB" ]]; then
    echo "ERROR: Input debian package not found: $INPUT_DEB" >&2
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(readlink -f "$OUTPUT_DIR")

# Create or validate working directory
if [[ -z "$WORKDIR" ]]; then
    WORKDIR=$(mktemp -d -t convert-deb-hf-XXXXXX)
else
    mkdir -p "$WORKDIR"
    WORKDIR=$(readlink -f "$WORKDIR")
fi

# Cleanup on exit unless --keep-temp is set
cleanup() {
    if [[ "$KEEP_TEMP" == "false" ]]; then
        echo ""
        echo "=== Cleaning up temporary directory ==="
        rm -rf "$WORKDIR"
    else
        echo ""
        echo "=== Temporary directory preserved: $WORKDIR ==="
    fi
}
trap cleanup EXIT

echo ""
echo "=== Convert Debian to Hardfork - Local Script ==="
echo "Input package:    $INPUT_DEB"
echo "Network:          $NETWORK_NAME"
echo "Output directory: $OUTPUT_DIR"
echo "Working directory: $WORKDIR"
echo ""


# Step 1: Get or download state dump
echo "=== Step 1: Getting state dump ==="
CONFIG_FILE="$WORKDIR/config.json"


if [[ "$STATE_DUMP_ARG" == gs://* ]]; then
    # Download from GCS path provided by user
    echo "Downloading state dump from GCS: $STATE_DUMP_ARG"
    if ! command -v gsutil &> /dev/null; then
        echo "ERROR: gsutil not found. Please install Google Cloud SDK or provide a local state dump file" >&2
        exit 1
    fi
    # Check if STATE_DUMP_ARG is a GCS folder
    if gsutil ls -d "$STATE_DUMP_ARG" 2>/dev/null | grep -q "/$"; then
        # Download newest from folder
        echo "Downloading state dump from GCS bucket: $STATE_DUMP_ARG"
        if ! command -v gsutil &> /dev/null; then
            echo "ERROR: gsutil not found. Please install Google Cloud SDK or provide a state dump file with -s" >&2
            exit 1
        fi
        set +o pipefail
        NEWEST_FILE=$(gsutil ls -l "$STATE_DUMP_ARG" | grep "devnet-state-dump" | sort -k2 -r | head -n1 | awk '{print $NF}' || true)
        set -o pipefail
        if [[ -z "$NEWEST_FILE" ]]; then
            echo "ERROR: No state dump files found in $STATE_DUMP_ARG" >&2
            exit 1
        fi
        echo "Newest state dump: $NEWEST_FILE"
        DOWNLOADED_FILE="$WORKDIR/downloaded_state_dump"
        if ! gsutil cp "$NEWEST_FILE" "$DOWNLOADED_FILE"; then
            echo "ERROR: Failed to download state dump from $NEWEST_FILE" >&2
            exit 1
        fi
        echo "\u2713 Downloaded state dump successfully"
        echo "Downloaded size: $(du -h "$DOWNLOADED_FILE" | cut -f1)"
        if [[ "$NEWEST_FILE" == *.gz ]] || file "$DOWNLOADED_FILE" | grep -q "gzip compressed"; then
            echo "Unpacking gzipped state dump..."
            gunzip -c "$DOWNLOADED_FILE" > "$CONFIG_FILE"
            echo "\u2713 State dump unpacked"
            rm "$DOWNLOADED_FILE"
        else
            mv "$DOWNLOADED_FILE" "$CONFIG_FILE"
        fi
        echo "State dump size: $(du -h "$CONFIG_FILE" | cut -f1)"
    else
        DOWNLOADED_FILE="$WORKDIR/downloaded_state_dump"
        if ! gsutil cp "$STATE_DUMP_ARG" "$DOWNLOADED_FILE"; then
            echo "ERROR: Failed to download state dump from $STATE_DUMP_ARG" >&2
            exit 1
        fi

        echo "\u2713 Downloaded state dump successfully"
        echo "Downloaded size: $(du -h "$DOWNLOADED_FILE" | cut -f1)"
        # Check if the downloaded file is gzipped and unpack if needed
        if [[ "$STATE_DUMP_ARG" == *.gz ]] || file "$DOWNLOADED_FILE" | grep -q "gzip compressed"; then
            echo "Unpacking gzipped state dump..."
            gunzip -c "$DOWNLOADED_FILE" > "$CONFIG_FILE"
            echo "\u2713 State dump unpacked"
            rm "$DOWNLOADED_FILE"
        else
            mv "$DOWNLOADED_FILE" "$CONFIG_FILE"
        fi
        echo "State dump size: $(du -h "$CONFIG_FILE" | cut -f1)"
    fi
else
    # Use provided local file
    if [[ ! -f "$STATE_DUMP_ARG" ]]; then
        echo "ERROR: Provided state dump file not found: $STATE_DUMP_ARG" >&2
        exit 1
    fi
    echo "Using provided state dump: $STATE_DUMP_ARG"
    if [[ "$STATE_DUMP_ARG" == *.gz ]]; then
        echo "Unpacking gzipped state dump..."
        gunzip -c "$STATE_DUMP_ARG" > "$CONFIG_FILE"
        echo "\u2713 State dump unpacked"
    else
        cp "$STATE_DUMP_ARG" "$CONFIG_FILE"
    fi
fi

# Verify it's valid JSON
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "ERROR: State dump file is not valid JSON" >&2
    exit 1
fi
echo "✓ State dump is valid JSON"

# Step 2: Generate hardfork ledger tarballs
echo ""
echo "=== Step 2: Generating hardfork ledger tarballs ==="
LEDGERS_DIR="$WORKDIR/hardfork_ledgers"
mkdir -p "$LEDGERS_DIR"

LEDGER_HASHES_JSON="$WORKDIR/hardfork_ledger_hashes.json"

# Check if mina-create-genesis is available
if ! command -v mina-create-genesis &> /dev/null; then
    echo "ERROR: mina-create-genesis not found on PATH" >&2
    echo "Please ensure mina tools are installed or in your PATH" >&2
    exit 1
fi

mina-create-genesis \
    --config-file "$CONFIG_FILE" \
    --genesis-dir "$LEDGERS_DIR/" \
    --hash-output-file "$LEDGER_HASHES_JSON" || {
    echo "ERROR: Failed to generate ledger tarballs" >&2
    exit 1
}

# Verify ledger tarballs were created
TARBALL_COUNT=$(find "$LEDGERS_DIR" -name "*.tar.gz" 2>/dev/null | wc -l)
if [[ $TARBALL_COUNT -eq 0 ]]; then
    echo "ERROR: No ledger tarballs were generated" >&2
    exit 1
fi
echo "✓ Generated $TARBALL_COUNT ledger tarball(s)"
ls -lh "$LEDGERS_DIR"/*.tar.gz

# Step 3: Create runtime config
echo ""
echo "=== Step 3: Creating runtime config ==="
RUNTIME_CONFIG_JSON="$WORKDIR/new_config.json"

# Get repository root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
FORKING_FROM_CONFIG_JSON="$REPO_ROOT/genesis_ledgers/${NETWORK_NAME}.json"

if [[ ! -f "$FORKING_FROM_CONFIG_JSON" ]]; then
    echo "WARNING: Base network config not found at $FORKING_FROM_CONFIG_JSON, using state dump" >&2
    cp "$CONFIG_FILE" "$RUNTIME_CONFIG_JSON"
else
    echo "Using base network config: $FORKING_FROM_CONFIG_JSON"
    export FORKING_FROM_CONFIG_JSON
    export FORK_CONFIG_JSON="$CONFIG_FILE"
    export LEDGER_HASHES_JSON="$LEDGER_HASHES_JSON"

    # Check if create_runtime_config.sh exists
    CREATE_RUNTIME_SCRIPT="$REPO_ROOT/scripts/hardfork/create_runtime_config.sh"
    if [[ ! -f "$CREATE_RUNTIME_SCRIPT" ]]; then
        echo "ERROR: Runtime config script not found: $CREATE_RUNTIME_SCRIPT" >&2
        exit 1
    fi

    "$CREATE_RUNTIME_SCRIPT" > "$RUNTIME_CONFIG_JSON"
fi

echo "✓ Runtime config created"
echo "Runtime config size: $(du -h "$RUNTIME_CONFIG_JSON" | cut -f1)"

# Step 4: Run the conversion script
echo ""
echo "=== Step 4: Converting debian package ==="

# Check if conversion script exists
CONVERSION_SCRIPT="$REPO_ROOT/scripts/hardfork/convert-daemon-debian-to-hf.sh"
if [[ ! -f "$CONVERSION_SCRIPT" ]]; then
    echo "ERROR: Conversion script not found: $CONVERSION_SCRIPT" >&2
    exit 1
fi

# Determine output filename
INPUT_DEB_ABS=$(readlink -f "$INPUT_DEB")
VERSION=$(dpkg-deb --field "$INPUT_DEB_ABS" Version)
ARCH=$(dpkg-deb --field "$INPUT_DEB_ABS" Architecture)
DEB_BASE=$(basename "$INPUT_DEB_ABS" .deb)

# Extract base name
FILE_BASE_NAME="${DEB_BASE%%_*}"

# Output path must match what convert-daemon-debian-to-hf.sh produces
OUTPUT_DEB="${OUTPUT_DIR}/${FILE_BASE_NAME}-hardfork_${VERSION}_${ARCH}.deb"


# Run the conversion script in a subshell to prevent trap overwriting
(
    "$CONVERSION_SCRIPT" \
        -d "$INPUT_DEB_ABS" \
        -c "$RUNTIME_CONFIG_JSON" \
        -l "$LEDGERS_DIR" \
        -n "$NETWORK_NAME" \
        -s "$SKIP_VERIFY"
)

# Verify output package was created
if [[ ! -f "$OUTPUT_DEB" ]]; then
    echo "ERROR: Output hardfork package not created at $OUTPUT_DEB" >&2
    exit 1
fi

echo ""
echo "=== Success! ==="
echo "Hardfork package created: $FINAL_OUTPUT"
echo "Package size: $(du -h "$FINAL_OUTPUT" | cut -f1)"
echo "Network: $NETWORK_NAME"
echo ""

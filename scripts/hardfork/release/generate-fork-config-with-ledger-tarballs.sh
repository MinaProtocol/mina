#!/usr/bin/env bash

set -ex

usage() {
  echo "Usage: $0 --network NETWORK_NAME --config-url CONFIG_JSON_GZ_URL --runtime-ledger RUNTIME_GENESIS_LEDGER --hard-fork-genesis-slot-delta HARD_FORK_GENESIS_SLOT_DELTA --logproc LOGPROC --output-dir OUTPUT_DIR"
  echo ""
  echo "Generates hardfork ledger tarballs and runtime config for the specified network."
  echo ""
  echo "Options:"
  echo "  --network NETWORK_NAME                 Name of the network (e.g., mainnet, testnet, devnet)"
  echo "  --config-url CONFIG_JSON_GZ_URL        URL to download the network configuration JSON file (gzipped)"
  echo "  --runtime-ledger RUNTIME_GENESIS_LEDGER   Path to the runtime genesis ledger generator executable"
  echo "  --logproc LOGPROC                      Command to process log output (e.g., cat, grep)"
  echo "  --output-dir OUTPUT_DIR                Directory to output the generated ledger tarballs. WARNING: will be cleared if it exists."
}

NETWORK_NAME=""
CONFIG_JSON_GZ_URL=""
RUNTIME_GENESIS_LEDGER=""
LOGPROC="cat"
OUTPUT_DIR="hardfork_ledgers"

TMP=$(mktemp -d)

HARD_FORK_SHIFT_SLOT_DELTA=0
PREFORK_GENESIS_CONFIG=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --network)
      NETWORK_NAME="$2"
      shift 2
      ;;
    --config-url)
      CONFIG_JSON_GZ_URL="$2"
      shift 2
      ;;
    --runtime-ledger)
      RUNTIME_GENESIS_LEDGER="$2"
      shift 2
      ;;
    --hardfork-shift-slot-delta)
      HARD_FORK_SHIFT_SLOT_DELTA="$2"
      shift 2
      ;;
    --prefork-genesis-config)
      PREFORK_GENESIS_CONFIG="$2"
      shift 2
      ;;
    --logproc)
      LOGPROC="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done


if [[ -z "$NETWORK_NAME" ]]; then
  echo "[ERROR] --network argument is required."
  usage
  exit 1
fi

if [[ -z "$CONFIG_JSON_GZ_URL" ]]; then
  echo "[ERROR] --config-url argument is required."
  usage
  exit 1
fi

if [[ -z "$RUNTIME_GENESIS_LEDGER" ]]; then
  echo "[ERROR] --runtime-ledger argument is required."
  usage
  exit 1
fi

# Info log
echo "[INFO] Network: $NETWORK_NAME"
echo "[INFO] Config URL: $CONFIG_JSON_GZ_URL"
echo "[INFO] Runtime Genesis Ledger: $RUNTIME_GENESIS_LEDGER"
echo "[INFO] Log Processor: $LOGPROC"

# Clean up any existing config files
echo "--- Clean up any existing config files"
rm -f config.json config.json.gz
rm -rf "$OUTPUT_DIR"

# Set the base network config for ./scripts/hardfork/create_runtime_config.sh
export FORKING_FROM_CONFIG_JSON="genesis_ledgers/${NETWORK_NAME}.json"
if [ ! -f "${FORKING_FROM_CONFIG_JSON}" ]; then
  echo "[ERROR] ${NETWORK_NAME} is not a known network name; check for existing network configs in 'genesis_ledgers/'"
  exit 1
fi

echo "--- Download and extract previous network config"
curl -sL "$CONFIG_JSON_GZ_URL" | gunzip > "$TMP/config.json"

# make sure files does not have genesis key
jq 'del(.genesis)' "$TMP/config.json" > "$TMP/fork_config_no_genesis.json"


echo "--- Generate hardfork ledger tarballs"
mkdir "$OUTPUT_DIR"

HARD_FORK_SHIFT_SLOT_DELTA_ARG=""
if [[ "$HARD_FORK_SHIFT_SLOT_DELTA" -ne 0 ]]; then
  jq 'del(.genesis)' "$PREFORK_GENESIS_CONFIG" > "$TMP/config_no_genesis.json"

  HARD_FORK_SHIFT_SLOT_DELTA_ARG="--hardfork-slot $HARD_FORK_SHIFT_SLOT_DELTA --prefork-genesis-config $TMP/config_no_genesis.json"
fi

"$RUNTIME_GENESIS_LEDGER" --pad-app-state --config-file "$TMP/fork_config_no_genesis.json" $HARD_FORK_SHIFT_SLOT_DELTA_ARG --genesis-dir "$OUTPUT_DIR"/ --hash-output-file hashes.json | tee runtime_genesis_ledger.log | $LOGPROC

echo "--- Create hardfork config"
FORK_CONFIG_JSON="$TMP/fork_config_no_genesis.json" LEDGER_HASHES_JSON=hashes.json scripts/hardfork/create_runtime_config.sh > new_config.json

echo "--- New genesis config"
cat new_config.json

echo "--- Ledger tarballs generated:"

ls -lh "$OUTPUT_DIR"/

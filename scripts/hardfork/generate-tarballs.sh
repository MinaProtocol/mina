#!/usr/bin/env bash

set -e

usage() {
  echo "Usage: $0 --network NETWORK_NAME --config-url CONFIG_JSON_GZ_URL --runtime-ledger RUNTIME_GENESIS_LEDGER --logproc LOGPROC"
  exit 1
}

NETWORK_NAME=""
CONFIG_JSON_GZ_URL=""
RUNTIME_GENESIS_LEDGER=""
LOGPROC="cat"

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
    --logproc)
      LOGPROC="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "$NETWORK_NAME" || -z "$CONFIG_JSON_GZ_URL" || -z "$RUNTIME_GENESIS_LEDGER" ]]; then
  usage
fi

# Info log
echo "[INFO] Network: $NETWORK_NAME"
echo "[INFO] Config URL: $CONFIG_JSON_GZ_URL"
echo "[INFO] Runtime Genesis Ledger: $RUNTIME_GENESIS_LEDGER"
echo "[INFO] Log Processor: $LOGPROC"

# Clean up any existing config files
echo "--- Clean up any existing config files"
rm -f config.json config.json.gz
rm -rf hardfork_ledgers

# Set the base network config for ./scripts/hardfork/create_runtime_config.sh
export FORKING_FROM_CONFIG_JSON="genesis_ledgers/${NETWORK_NAME}.json"
if [ ! -f "${FORKING_FROM_CONFIG_JSON}" ]; then
  echo "[ERROR] ${NETWORK_NAME} is not a known network name; check for existing network configs in 'genesis_ledgers/'"
  exit 1
fi

echo "--- Download and extract previous network config"
curl -o config.json.gz "$CONFIG_JSON_GZ_URL"
gunzip config.json.gz

echo "--- Generate hardfork ledger tarballs"
mkdir hardfork_ledgers

"$RUNTIME_GENESIS_LEDGER" --config-file config.json --genesis-dir hardfork_ledgers/ --hash-output-file hardfork_ledger_hashes.json | tee runtime_genesis_ledger.log | $LOGPROC

echo "--- Create hardfork config"
FORK_CONFIG_JSON=config.json LEDGER_HASHES_JSON=hardfork_ledger_hashes.json scripts/hardfork/create_runtime_config.sh > new_config.json

echo "--- New genesis config"
head new_config.json

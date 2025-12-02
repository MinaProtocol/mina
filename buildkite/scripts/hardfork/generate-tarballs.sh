#!/usr/bin/env bash

set -e

usage() {
  echo "Usage: $0 --network NETWORK_NAME --config-url CONFIG_JSON_GZ_URL --codename CODENAME"
  exit 1
}

NETWORK_NAME=""
CONFIG_JSON_GZ_URL=""
CODENAME=

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
    --codename)
      CODENAME="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "$NETWORK_NAME" || -z "$CONFIG_JSON_GZ_URL" || -z "$CODENAME" ]]; then
  usage
fi

echo "--- Restoring cached build artifacts for apps/${CODENAME}/"

prefix=apps/${CODENAME}/

./buildkite/scripts/cache/manager.sh read $prefix/logproc.exe $prefix/runtime_genesis_ledger.exe .

echo "--- Generating ledger tarballs for hardfork network: $NETWORK_NAME"

./scripts/hardfork/generate-tarballs.sh --network "$NETWORK_NAME" --config-url "$CONFIG_JSON_GZ_URL" --runtime-ledger ./runtime_genesis_ledger.exe --logproc ./logproc.exe

./buildkite/scripts/cache/manager.sh write hardfork_ledgers/*.tar.gz hardfork/ledgers/
./buildkite/scripts/cache/manager.sh write new_config.json hardfork/
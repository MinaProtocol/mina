#!/usr/bin/env bash

set -ex

usage() {
  echo "Usage: $0 --network NETWORK_NAME --config-url CONFIG_JSON_GZ_URL --codename CODENAME"
  exit 1
}

NETWORK_NAME=""
CONFIG_JSON_GZ_URL=""
CODENAME=""
CACHED_BUILDKITE_BUILD_ID=""
HARD_FORK_GENESIS_SLOT_DELTA=""

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
    --cached-buildkite-build-id)
      CACHED_BUILDKITE_BUILD_ID="$2"
      shift 2
      ;;
    --hard-fork-genesis-slot-delta)
      HARDFORK_GENESIS_SLOT_DELTA="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done


if [[ -z "$NETWORK_NAME" ]]; then
  echo "Error: --network is required."
  usage
fi
if [[ -z "$CONFIG_JSON_GZ_URL" ]]; then
  echo "Error: --config-url is required."
  usage
fi
if [[ -z "$CODENAME" ]]; then
  echo "Error: --codename is required."
  usage
fi


HARD_FORK_GENESIS_SLOT_DELTA_ARG=""
if [[ -n "$HARDFORK_GENESIS_SLOT_DELTA" ]]; then
  HARD_FORK_GENESIS_SLOT_DELTA_ARG="--hardfork-shift-slot-delta $HARDFORK_GENESIS_SLOT_DELTA"
fi

echo "--- Restoring cached build artifacts for apps/${CODENAME}/"

# Install mina-logproc from cached build if available, else from current build
if [[ -n "${CACHED_BUILDKITE_BUILD_ID:-}" ]]; then
  MINA_DEB_CODENAME=$CODENAME FORCE_VERSION="*" ROOT="$CACHED_BUILDKITE_BUILD_ID" ./buildkite/scripts/debian/install.sh mina-${NETWORK_NAME} 1
else
  MINA_DEB_CODENAME=$CODENAME ./buildkite/scripts/debian/install.sh mina-${NETWORK_NAME} 1
fi

echo "--- Generating ledger tarballs for hardfork network: $NETWORK_NAME"

./scripts/hardfork/release/generate-fork-config-with-ledger-tarballs.sh --network "$NETWORK_NAME" --config-url "$CONFIG_JSON_GZ_URL" --runtime-ledger mina-create-genesis --logproc mina-logproc $HARD_FORK_GENESIS_SLOT_DELTA_ARG

./scripts/hardfork/release/upload-ledger-tarballs.sh hardfork_ledgers new_config.json

# Write to cache
./buildkite/scripts/cache/manager.sh write-to-dir hardfork_ledgers/*.tar.gz hardfork/ledgers/
./buildkite/scripts/cache/manager.sh write-to-dir hashes.json new_config.json hardfork/

# Clean up generated ledgers and config
rm -rf hardfork_ledgers hashes.json new_config.json
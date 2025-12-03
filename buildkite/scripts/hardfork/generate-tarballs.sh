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
    *)
      usage
      ;;
  esac
done

if [[ -z "$NETWORK_NAME" || -z "$CONFIG_JSON_GZ_URL" || -z "$CODENAME" ]]; then
  usage
fi

echo "--- Restoring cached build artifacts for apps/${CODENAME}/"

if [[ -n "$CACHED_BUILDKITE_BUILD_ID" ]]; then
  export ROOT="$CACHED_BUILDKITE_BUILD_ID"
  export FORCE_VERSION="*"
fi
MINA_DEB_CODENAME="$CODENAME" ./buildkite/scripts/debian/install.sh mina-${NETWORK_NAME} 1
echo "--- Generating ledger tarballs for hardfork network: $NETWORK_NAME"

./scripts/hardfork/generate-tarballs.sh --network "$NETWORK_NAME" --config-url "$CONFIG_JSON_GZ_URL" --runtime-ledger mina-create-genesis --logproc mina-logproc

./buildkite/scripts/cache/manager.sh write hardfork_ledgers/*.tar.gz hardfork/ledgers/
./buildkite/scripts/cache/manager.sh write new_config.json hardfork/
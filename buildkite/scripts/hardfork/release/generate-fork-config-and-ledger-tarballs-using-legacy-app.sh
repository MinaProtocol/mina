#!/bin/bash

set -ex

NETWORK="devnet"
CODENAME=""
WORKDIR=$(pwd)
FORCE_VERSION="*"
CACHED_BUILDKITE_BUILD_ID="${CACHED_BUILDKITE_BUILD_ID:-}"
CONFIG_JSON_GZ_URL=""
HARD_FORK_SHIFT_SLOT_DELTA=""
PREFORK_GENESIS_CONFIG=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --network)
      NETWORK="$2"
      shift 2
      ;;
    --version)
      FORCE_VERSION="$2"
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
    --config-json-gz-url)
      CONFIG_JSON_GZ_URL="$2"
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
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 --network <network> --config-json-gz-url <url> [--version <version>] --codename <codename> [--cached-buildkite-build-id <id>]"
      exit 1
      ;;
  esac
done

APP_NAME="mina-$NETWORK-pre-hardfork-mesa"

if [ -z "$NETWORK" ] || [ -z "$CODENAME" ]; then
  echo "Usage: $0 --network <network> [--version <version>] --codename <codename>"
  exit 1
fi

HARD_FORK_SHIFT_SLOT_DELTA_ARG=""
if [[ -n "$HARD_FORK_SHIFT_SLOT_DELTA" ]]; then
  HARD_FORK_SHIFT_SLOT_DELTA_ARG="--hardfork-shift-slot-delta $HARD_FORK_SHIFT_SLOT_DELTA --prefork-genesis-config $PREFORK_GENESIS_CONFIG"
fi

# Install mina-logproc from cached build if available, else from current build
if [[ -n "${CACHED_BUILDKITE_BUILD_ID:-}" ]]; then
  MINA_DEB_CODENAME=$CODENAME FORCE_VERSION="*" ROOT="$CACHED_BUILDKITE_BUILD_ID" ./buildkite/scripts/debian/install.sh mina-logproc 1
else
  MINA_DEB_CODENAME=$CODENAME ./buildkite/scripts/debian/install.sh mina-logproc 1
fi

MINA_DEB_CODENAME=$CODENAME FORCE_VERSION=$FORCE_VERSION ROOT="legacy" ./buildkite/scripts/debian/install.sh "$APP_NAME" 1

curl "${CONFIG_JSON_GZ_URL}" > config.json.gz && gunzip config.json.gz

./scripts/hardfork/release/generate-fork-config-with-ledger-tarballs-using-legacy-app.sh --exe "$APP_NAME" --config "config.json" --workdir "$WORKDIR" $HARD_FORK_SHIFT_SLOT_DELTA_ARG
echo "--- Caching legacy ledger tarballs and hashes"

ls -lh $WORKDIR/legacy_ledgers/

head -n 10 "$WORKDIR/legacy_hashes.json"

./buildkite/scripts/cache/manager.sh write-to-dir "$WORKDIR/legacy_hashes.json" "$WORKDIR/legacy_ledgers/*.tar.gz" "hardfork/legacy/"

#clean up generated ledgers and config
rm -rf "$WORKDIR/legacy_ledgers" "$WORKDIR/legacy_hashes.json" config.json
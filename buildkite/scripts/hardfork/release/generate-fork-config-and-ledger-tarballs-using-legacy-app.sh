#!/bin/bash

set -ex

NETWORK="devnet"
CODENAME=""
WORKDIR=$(pwd)
FORCE_VERSION="*"
CACHED_BUILDKITE_BUILD_ID="${CACHED_BUILDKITE_BUILD_ID:-}"
CONFIG_JSON_GZ_URL=""
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
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 --network <network> --config-json-gz-url <url> [--version <version>] --codename <codename> [--cached-buildkite-build-id <id>]"
      exit 1
      ;;
  esac
done

if [ -z "$NETWORK" ] || [ -z "$CODENAME" ]; then
  echo "Usage: $0 --network <network> [--version <version>] --codename <codename>"
  exit 1
fi

# Install mina-logproc from cached build if available, else from current build
if [[ -n "${CACHED_BUILDKITE_BUILD_ID:-}" ]]; then
  MINA_DEB_CODENAME=$CODENAME FORCE_VERSION="*" ROOT="$CACHED_BUILDKITE_BUILD_ID" ./buildkite/scripts/debian/install.sh mina-logproc 1
else
  MINA_DEB_CODENAME=$CODENAME ./buildkite/scripts/debian/install.sh mina-logproc 1
fi

MINA_DEB_CODENAME=$CODENAME FORCE_VERSION=$FORCE_VERSION ROOT="legacy" ./buildkite/scripts/debian/install.sh mina-create-$NETWORK-prefork-genesis-ledger 1

curl "${CONFIG_JSON_GZ_URL}" > config.json.gz && gunzip config.json.gz

# The create-prefork-genesis package ships no /etc/coda/build_config/PROFILE
# file (that comes with mina-<network>-profile), so the build profile is
# passed through MINA_PROFILE. Same mapping as Profiles.fromNetwork in
# buildkite/src/Constants/Profiles.dhall.
case "$NETWORK" in
  mainnet) MINA_PROFILE="mainnet" ;;
  devnet) MINA_PROFILE="devnet" ;;
  *)
    echo "No build profile known for network '$NETWORK'" >&2
    exit 1
    ;;
esac
export MINA_PROFILE

./scripts/hardfork/release/generate-fork-config-with-ledger-tarballs-using-legacy-app.sh --exe mina-create-prefork-genesis --config "config.json" --workdir "$WORKDIR" --prefork-genesis-config "genesis_ledgers/${NETWORK}.json"

echo "--- Caching legacy ledger tarballs and hashes"

ls -lh $WORKDIR/legacy_ledgers/

head -n 10 "$WORKDIR/legacy_hashes.json"

buildkite-cache-manager write "$WORKDIR/legacy_hashes.json" "$WORKDIR/legacy_ledgers/*.tar.gz" "hardfork/legacy/"

#clean up generated ledgers and config
rm -rf "$WORKDIR/legacy_ledgers" "$WORKDIR/legacy_hashes.json" config.json

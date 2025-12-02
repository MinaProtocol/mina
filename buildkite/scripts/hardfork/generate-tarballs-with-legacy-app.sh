#!/bin/bash

set -e

NETWORK="devnet"
VERSION=""
CODENAME=""
WORKDIR=$(pwd)

while [[ $# -gt 0 ]]; do
  case $1 in
    --network)
      NETWORK="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --codename)
      CODENAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 --network <network> --version <version> --codename <codename>"
      exit 1
      ;;
  esac
done

if [ -z "$NETWORK" ] || [ -z "$VERSION" ]; then
  echo "Usage: $0 --network <network> --version <version>"
  exit 1
fi


MINA_DEB_CODENAME=$CODENAME FORCE_VERSION="$VERSION" ./buildkite/scripts/debian/install.sh mina-create-legacy-genesis 1

./buildkite/scripts/cache/manager.sh read "hardfork/new_config.json" .

"mina-create-legacy-genesis" --config-file "new_config.json" --genesis-dir "$WORKDIR/legacy_ledgers" --hash-output-file "$WORKDIR/legacy_hashes.json"

echo "--- Caching legacy ledger tarballs and hashes"

ls -lh $WORKDIR/legacy_ledgers/

head -n 10 "$WORKDIR/legacy_hashes.json"

./buildkite/scripts/cache/manager.sh write "$WORKDIR/legacy_hashes.json" "$WORKDIR/legacy_ledgers/*.tar.gz" "hardfork/legacy"

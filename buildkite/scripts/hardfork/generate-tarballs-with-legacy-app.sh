#!/bin/bash

set -e

NETWORK="devnet"
CODENAME=""
WORKDIR=$(pwd)

while [[ $# -gt 0 ]]; do
  case $1 in
    --network)
      NETWORK="$2"
      shift 2
      ;;
    --version)
      export FORCE_VERSION="$2"
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

if [ -z "$NETWORK" ] || [ -z "$VERSION" ] || [ -z "$CODENAME" ]; then
  echo "Usage: $0 --network <network> --version <version> --codename <codename>"
  exit 1
fi


MINA_DEB_CODENAME=$CODENAME ./buildkite/scripts/debian/install.sh mina-create-legacy-genesis 1

./buildkite/scripts/cache/manager.sh read "hardfork/new_config.json" .

"mina-create-legacy-genesis" --config-file "new_config.json" --genesis-dir "$WORKDIR/legacy_ledgers" --hash-output-file "$WORKDIR/legacy_hashes.json"

echo "--- Caching legacy ledger tarballs and hashes"

ls -lh $WORKDIR/legacy_ledgers/

head -n 10 "$WORKDIR/legacy_hashes.json"

./buildkite/scripts/cache/manager.sh write "$WORKDIR/legacy_hashes.json" "$WORKDIR/legacy_ledgers/*.tar.gz" "hardfork/legacy"

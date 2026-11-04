#!/usr/bin/env bash

# Take a ready hardfork config, as scripts/hardfork/release/publish-hardfork-config.sh
# uploaded it, and write it to this build's cache in the layout the packaging
# and the verification steps read, the same layout
# generate-fork-config-and-ledger-tarballs.sh and its legacy-app twin write:
#
#   <prefix>/new_config.json           the runtime config that goes into the package
#   <prefix>/hashes.json               the ledger hashes, as mina-create-genesis writes them
#   <prefix>/ledgers/*.tar.gz          the migrated ledger tarballs
#   <prefix>/legacy/legacy_hashes.json the legacy ledger hashes
#   <prefix>/legacy/*.tar.gz           the legacy ledger tarballs
#
# So the packages are built from the ready config, in seconds, instead of
# waiting for the ledgers to be rebuilt from the state dump. The rebuild still
# runs, in parallel, as a check (compare-hardfork-data.sh).
#
# The config must come from the same tip as the state dump the verification
# steps use: the fork block state hash in daemon.json must equal the one in the
# dump, or this script stops. A config taken one block later than the dump is
# the first thing this catches.
#
# The ledger tarballs are uploaded to MINA_LEDGER_S3_BUCKET, where a daemon
# downloads them when they are not packaged, exactly as the generation step
# does (upload-ledger-tarballs.sh). GENESIS_TIMESTAMP, when set, becomes the
# genesis timestamp of the packaged config, as in the generation step.
#
# Usage:
#   fetch-hardfork-config.sh --network <name> --url <https url of the archive> \
#       --config-json-gz-url <url of the state dump> [--cache-prefix hardfork]

set -euo pipefail

NETWORK=""
URL=""
CONFIG_JSON_GZ_URL=""
CACHE_PREFIX="hardfork"

usage() {
  sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --network) NETWORK="$2"; shift 2 ;;
    --url) URL="$2"; shift 2 ;;
    --config-json-gz-url) CONFIG_JSON_GZ_URL="$2"; shift 2 ;;
    --cache-prefix) CACHE_PREFIX="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[[ -n "$NETWORK" && -n "$URL" && -n "$CONFIG_JSON_GZ_URL" ]] || usage

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
CONFIG_DIR="$WORKDIR/config"
mkdir -p "$CONFIG_DIR"

echo "--- Downloading the hardfork config from $URL"
curl -sSfL "$URL" | tar -xz -C "$CONFIG_DIR"

echo "--- Checking the config directory"
fail=0
check() { if [[ ! -e "$CONFIG_DIR/$1" ]]; then echo "❌ missing: $1" >&2; fail=1; fi; }
check activated
check daemon.json
check fork_validation/legacy/daemon.json
for d in genesis fork_validation/legacy/genesis; do
  n=$(find "$CONFIG_DIR/$d" -maxdepth 1 -name '*.tar.gz' 2>/dev/null | wc -l)
  if [[ "$n" -ne 3 ]]; then echo "❌ $d holds $n ledger tarballs, expected 3" >&2; fail=1; fi
done
[[ "$fail" == 0 ]] || exit 1

echo "--- Checking that the config and the state dump describe the same fork block"
CONFIG_STATE_HASH=$(jq -r '.proof.fork.state_hash // empty' "$CONFIG_DIR/daemon.json")
DUMP_STATE_HASH=$(curl -sSfL "$CONFIG_JSON_GZ_URL" | gunzip | jq -r '.proof.fork.state_hash // empty')
echo "config: $CONFIG_STATE_HASH"
echo "dump:   $DUMP_STATE_HASH"
if [[ -z "$CONFIG_STATE_HASH" || "$CONFIG_STATE_HASH" != "$DUMP_STATE_HASH" ]]; then
  echo "❌ The hardfork config and the state dump are not from the same fork block." >&2
  exit 1
fi

# The hashes file as mina-create-genesis writes it (--hash-output-file): the
# ledger hashes and tarball hashes of the three ledgers, and nothing else.
hashes_of() {
  jq '{ ledger: { hash: .ledger.hash, s3_data_hash: .ledger.s3_data_hash }
      , epoch_data:
          { staking: { hash: .epoch_data.staking.hash, s3_data_hash: .epoch_data.staking.s3_data_hash }
          , next: { hash: .epoch_data.next.hash, s3_data_hash: .epoch_data.next.s3_data_hash } } }' "$1"
}

echo "--- Preparing the packaged config"
mkdir -p "$WORKDIR/hardfork_ledgers" "$WORKDIR/legacy_ledgers"
cp "$CONFIG_DIR"/genesis/*.tar.gz "$WORKDIR/hardfork_ledgers/"
cp "$CONFIG_DIR"/fork_validation/legacy/genesis/*.tar.gz "$WORKDIR/legacy_ledgers/"
hashes_of "$CONFIG_DIR/daemon.json" > "$WORKDIR/hashes.json"
hashes_of "$CONFIG_DIR/fork_validation/legacy/daemon.json" > "$WORKDIR/legacy_hashes.json"
# daemon.json carries the fork block, the seeds and the hashes; the script
# takes those and sets the genesis timestamp, as it does for a generated config.
FORK_CONFIG_JSON="$CONFIG_DIR/daemon.json" LEDGER_HASHES_JSON="$WORKDIR/hashes.json" \
  ./scripts/hardfork/create_runtime_config.sh > "$WORKDIR/new_config.json"
cat "$WORKDIR/new_config.json"

echo "--- Uploading the ledger tarballs for daemons that download them"
./scripts/hardfork/release/upload-ledger-tarballs.sh "$WORKDIR/hardfork_ledgers" "$WORKDIR/new_config.json"

echo "--- Writing the hardfork data to the build cache under $CACHE_PREFIX/"
buildkite-cache-manager write "$WORKDIR"/hardfork_ledgers/*.tar.gz "$CACHE_PREFIX/ledgers/"
buildkite-cache-manager write "$WORKDIR/hashes.json" "$WORKDIR/new_config.json" "$CACHE_PREFIX/"
buildkite-cache-manager write "$WORKDIR/legacy_hashes.json" "$WORKDIR"/legacy_ledgers/*.tar.gz "$CACHE_PREFIX/legacy/"

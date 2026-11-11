#!/usr/bin/env bash

# Take a ready hardfork config, the archive of the directory
# `mina advanced generate-hardfork-config` writes, which the mina-state-dump job
# uploads, and write it to this build's cache in the layout the packaging and
# the verification read, the same layout generate-fork-config-and-ledger-tarballs.sh
# and its legacy-app twin write:
#
#   <prefix>/new_config.json           the runtime config that goes into the package
#   <prefix>/hashes.json               the ledger hashes, as mina-create-genesis writes them
#   <prefix>/ledgers/*.tar.gz          the migrated ledger tarballs
#   <prefix>/legacy/legacy_hashes.json the legacy ledger hashes
#   <prefix>/legacy/*.tar.gz           the legacy ledger tarballs
#
# Nothing is rebuilt from the state dump. The verification compares the package
# with the fork block (the block check) and every account with the dump (the
# accounts check), so the dump must be from the same fork block as the config.
# This script stops if it is not.
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
curl -sSfL "$URL" -o "$WORKDIR/config.tar.gz"

# The daemon writes only regular files and directories. Anything else is refused
# before it is extracted: a symlink in place of a tarball would be followed by
# the copies below, and a file of this agent uploaded publicly. The listing is
# read first: under pipefail, `tar | grep -q` reports a match as a failure.
listing=$(tar -tvzf "$WORKDIR/config.tar.gz")
unexpected=$(grep -v '^[-d]' <<< "$listing" || true)
if [[ -n "$unexpected" ]]; then
  echo "❌ the hardfork config holds entries other than files and directories:" >&2
  echo "$unexpected" >&2
  exit 1
fi
tar -xzf "$WORKDIR/config.tar.gz" -C "$CONFIG_DIR" --no-same-owner --no-same-permissions
unexpected=$(find "$CONFIG_DIR" ! -type f ! -type d)
if [[ -n "$unexpected" ]]; then
  echo "❌ the extracted config holds entries other than files and directories:" >&2
  echo "$unexpected" >&2
  exit 1
fi

echo "--- Checking the config directory"
fail=0
check() { if [[ ! -f "$CONFIG_DIR/$1" ]]; then echo "❌ missing: $1" >&2; fail=1; fi; }
check activated
check daemon.json
check fork_validation/legacy/daemon.json
[[ "$fail" == 0 ]] || exit 1

for dir in "" fork_validation/legacy/; do
  if ! jq -e '[.ledger, .epoch_data.staking, .epoch_data.next] |
              all(.hash, .s3_data_hash | type == "string" and length > 0)' \
    "$CONFIG_DIR/${dir}daemon.json" > /dev/null; then
    echo "❌ ${dir}daemon.json does not hold the hash and s3_data_hash of all three ledgers" >&2
    exit 1
  fi
  # Equal staking and next ledgers share one tarball.
  expected=$(jq -r '[.ledger.s3_data_hash, .epoch_data.staking.s3_data_hash, .epoch_data.next.s3_data_hash] |
                    unique | length' "$CONFIG_DIR/${dir}daemon.json")
  n=$(find "$CONFIG_DIR/${dir}genesis" -maxdepth 1 -type f -name '*.tar.gz' 2>/dev/null | wc -l)
  if [[ "$n" -ne "$expected" ]]; then
    echo "❌ ${dir}genesis holds $n ledger tarballs, expected $expected" >&2
    exit 1
  fi
done

echo "--- Checking that the config and the state dump describe the same fork block"
curl -sSfL "$CONFIG_JSON_GZ_URL" -o "$WORKDIR/dump.json.gz"
dump_field() { gunzip -c "$WORKDIR/dump.json.gz" | jq -r "$1 // empty"; }
CONFIG_STATE_HASH=$(jq -r '.proof.fork.state_hash // empty' "$CONFIG_DIR/daemon.json")
DUMP_STATE_HASH=$(dump_field '.proof.fork.state_hash')
echo "config: $CONFIG_STATE_HASH"
echo "dump:   $DUMP_STATE_HASH"
if [[ -z "$CONFIG_STATE_HASH" || "$CONFIG_STATE_HASH" != "$DUMP_STATE_HASH" ]]; then
  echo "❌ The hardfork config and the state dump are not from the same fork block." >&2
  exit 1
fi

# The legacy ledgers are the daemon's own, not rebuilt by a prefork release
# from the dump as the reference step does. The dump's ledger hash, which the
# preflight compares with the fork block, ties the legacy genesis ledger to the
# chain. The dump holds no hash for the epoch ledgers.
echo "--- Checking the legacy genesis ledger against the state dump"
LEGACY_LEDGER_HASH=$(jq -r '.ledger.hash' "$CONFIG_DIR/fork_validation/legacy/daemon.json")
DUMP_LEDGER_HASH=$(dump_field '.ledger.hash')
echo "legacy: $LEGACY_LEDGER_HASH"
echo "dump:   $DUMP_LEDGER_HASH"
if [[ -z "$DUMP_LEDGER_HASH" ]]; then
  echo "❌ The state dump holds no ledger hash." >&2
  exit 1
fi
if [[ "$LEGACY_LEDGER_HASH" != "$DUMP_LEDGER_HASH" ]]; then
  echo "❌ The legacy genesis ledger of the hardfork config is not the ledger of the state dump." >&2
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
  FORKING_FROM_CONFIG_JSON="genesis_ledgers/${NETWORK}.json" \
  ./scripts/hardfork/create_runtime_config.sh > "$WORKDIR/new_config.json"
cat "$WORKDIR/new_config.json"

echo "--- Uploading the ledger tarballs for daemons that download them"
./scripts/hardfork/release/upload-ledger-tarballs.sh "$WORKDIR/hardfork_ledgers" "$WORKDIR/new_config.json"

echo "--- Writing the hardfork data to the build cache under $CACHE_PREFIX/"
buildkite-cache-manager write "$WORKDIR"/hardfork_ledgers/*.tar.gz "$CACHE_PREFIX/ledgers/"
buildkite-cache-manager write "$WORKDIR/hashes.json" "$WORKDIR/new_config.json" "$CACHE_PREFIX/"
buildkite-cache-manager write "$WORKDIR/legacy_hashes.json" "$WORKDIR"/legacy_ledgers/*.tar.gz "$CACHE_PREFIX/legacy/"

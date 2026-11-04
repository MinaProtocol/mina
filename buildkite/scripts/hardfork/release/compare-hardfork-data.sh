#!/usr/bin/env bash

# Compare the ready hardfork config (fetch-hardfork-config.sh) with the one
# rebuilt from the state dump (generate-fork-config-and-ledger-tarballs.sh and
# its legacy-app twin, run with --cache-prefix on the same build), both read
# from this build's cache.
#
# What must agree: the merkle root of each of the three migrated ledgers and
# of the three legacy ledgers, and the fork block. That is what a daemon
# checks a ledger against. The tarball hashes (s3_data_hash) are left out on
# purpose: two tar.gz of the same ledger differ in bytes, and the tarballs
# check of the verification step compares their contents.
#
# Usage:
#   compare-hardfork-data.sh --ready hardfork --recomputed hardfork-recomputed

set -euo pipefail

READY=""
RECOMPUTED=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ready) READY="$2"; shift 2 ;;
    --recomputed) RECOMPUTED="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done
[[ -n "$READY" && -n "$RECOMPUTED" ]] || { echo "Usage: $0 --ready <prefix> --recomputed <prefix>" >&2; exit 1; }

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo "--- Reading both from the build cache"
buildkite-cache-manager read "$READY/hashes.json" "$READY/new_config.json" "$READY/legacy/legacy_hashes.json" "$WORKDIR/ready"
buildkite-cache-manager read "$RECOMPUTED/hashes.json" "$RECOMPUTED/new_config.json" "$RECOMPUTED/legacy/legacy_hashes.json" "$WORKDIR/recomputed"

# The ledger hashes of a hashes file, in a fixed order.
roots() { jq -S '{ ledger: .ledger.hash, staking: .epoch_data.staking.hash, next: .epoch_data.next.hash }' "$1"; }
fork() { jq -S '.proof.fork' "$1"; }

fail=0
compare() {
  local what="$1" a="$2" b="$3"
  echo "--- $what"
  echo "ready:      $(tr -d '\n ' < "$a")"
  echo "recomputed: $(tr -d '\n ' < "$b")"
  if cmp -s "$a" "$b"; then echo "✅ same"; else echo "❌ differ" >&2; fail=1; fi
}

roots "$WORKDIR/ready/hashes.json" > "$WORKDIR/a"; roots "$WORKDIR/recomputed/hashes.json" > "$WORKDIR/b"
compare "Migrated ledger roots" "$WORKDIR/a" "$WORKDIR/b"

roots "$WORKDIR/ready/legacy_hashes.json" > "$WORKDIR/a"; roots "$WORKDIR/recomputed/legacy_hashes.json" > "$WORKDIR/b"
compare "Legacy ledger roots" "$WORKDIR/a" "$WORKDIR/b"

fork "$WORKDIR/ready/new_config.json" > "$WORKDIR/a"; fork "$WORKDIR/recomputed/new_config.json" > "$WORKDIR/b"
compare "Fork block" "$WORKDIR/a" "$WORKDIR/b"

if [[ "$fail" != 0 ]]; then
  echo "❌ The ready hardfork config does not match the one rebuilt from the state dump." >&2
  exit 1
fi
echo "✅ The ready hardfork config matches the one rebuilt from the state dump."

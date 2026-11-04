#!/usr/bin/env bash

# Upload a hardfork config directory, as `mina advanced generate-hardfork-config`
# writes it, to a GCS bucket as one archive, for the hardfork package pipeline
# to read (HARDFORK_CONFIG_URL in buildkite/scripts/entrypoints/run-hardfork-package-gen.sh).
#
# The directory holds:
#
#   daemon.json                      the new runtime config: fork block, seeds,
#                                    ledger hashes and tarball hashes
#   genesis/*.tar.gz                 the three migrated ledgers
#   fork_validation/legacy/          the same, for the legacy (pre-fork) ledgers;
#                                    the pipeline verifies against them
#   activated                        written last by the daemon: the directory
#                                    is complete
#
# It is archived whole, so that a reader never sees a partial directory, and
# named by the fork block's state hash, so that it can be paired with the state
# dump taken from the same tip:
#
#   <network>-hardfork-config-<state hash>.tar.gz
#
# Run it on the node that produced the state dump, right after the dump, so
# that both describe the same tip. With --generate it asks the daemon for the
# directory first (the daemon must run on this host, with its client port
# reachable).
#
# Usage:
#   publish-hardfork-config.sh --network <mainnet|devnet> --bucket gs://<bucket> \
#       --config-dir <dir> [--generate] [--daemon-port <port>]
#
# Prints the https URL of the archive on the last line.

set -euo pipefail

NETWORK=""
BUCKET=""
CONFIG_DIR=""
GENERATE=0
DAEMON_PORT=""

usage() {
  sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --network) NETWORK="$2"; shift 2 ;;
    --bucket) BUCKET="$2"; shift 2 ;;
    --config-dir) CONFIG_DIR="$2"; shift 2 ;;
    --generate) GENERATE=1; shift ;;
    --daemon-port) DAEMON_PORT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[[ -n "$NETWORK" && -n "$BUCKET" && -n "$CONFIG_DIR" ]] || usage
[[ "$BUCKET" =~ ^gs://[^/]+(/.*)?$ ]] || { echo "❌ --bucket must be gs://<bucket>[/<prefix>] (got '$BUCKET')" >&2; exit 1; }
BUCKET="${BUCKET%/}"

if [[ "$GENERATE" == 1 ]]; then
  port_arg=()
  [[ -n "$DAEMON_PORT" ]] && port_arg=(--daemon-port "$DAEMON_PORT")
  echo "--- Asking the daemon for a hardfork config in $CONFIG_DIR"
  mina advanced generate-hardfork-config --hardfork-config-dir "$CONFIG_DIR" "${port_arg[@]}"
fi

echo "--- Checking $CONFIG_DIR"
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

STATE_HASH=$(jq -r '.proof.fork.state_hash // empty' "$CONFIG_DIR/daemon.json")
[[ -n "$STATE_HASH" ]] || { echo "❌ daemon.json has no proof.fork.state_hash" >&2; exit 1; }
LEGACY_STATE_HASH=$(jq -r '.proof.fork.state_hash // empty' "$CONFIG_DIR/fork_validation/legacy/daemon.json")
if [[ "$LEGACY_STATE_HASH" != "$STATE_HASH" ]]; then
  echo "❌ the legacy config is for another fork block ($LEGACY_STATE_HASH, not $STATE_HASH)" >&2
  exit 1
fi

ARCHIVE="${NETWORK}-hardfork-config-${STATE_HASH}.tar.gz"
echo "--- Archiving $CONFIG_DIR as $ARCHIVE"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# The daemon's build directory, when it is still there, is not part of the config.
tar -C "$CONFIG_DIR" --exclude=_build -czf "$tmp/$ARCHIVE" .
ls -lh "$tmp/$ARCHIVE"

echo "--- Uploading to $BUCKET/$ARCHIVE"
gsutil cp "$tmp/$ARCHIVE" "$BUCKET/$ARCHIVE"

echo "https://storage.googleapis.com/${BUCKET#gs://}/$ARCHIVE"

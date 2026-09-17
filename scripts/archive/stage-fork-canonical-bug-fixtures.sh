#!/bin/bash

# stage-fork-canonical-bug-fixtures.sh
#
# One-time fixture builder for the archive fork-canonical bug repro test
# (src/test/archive/archive_node_tests/archive_fork_canonical_bug_test.ml).
#
# What it does:
#   1. Restores a POST-fork archive dump locally into a scratch postgres db
#      (the post-fork dump is needed because it contains chain B's first
#      few blocks; the pre-fork dump does not).
#   2. Runs mina-extract-blocks to dump chain B 6816-6819 in extensional
#      format.
#   3. Bundles those JSONs as precomputed_blocks.tar.xz.
#   4. Copies the supplied prefork dump, post-fork runtime config, and
#      chain B blocks bundle into one fixture folder.
#   5. (Optional) rsyncs the staged folder to Hetzner test_data.
#
# This script is intended to be run ONCE; the artifacts it produces are
# checked into the Hetzner test_data folder for downstream CI runs.
#
# USAGE:
#   ./stage-fork-canonical-bug-fixtures.sh \
#       --prefork-dump <path-to-prefork.sql.tar> \
#       --postfork-dump <path-to-postfork.sql.tar> \
#       --runtime-config <path-to-new_config.json> \
#       --output <staging-dir> \
#       [--upload-to-hetzner]
#
# CHAIN B BLOCKS extracted:
#   6816 3NL5YRUKggVqZaGazgNhbWMydcSJnPQtcu5PBfyEwbsHboynPMP1
#   6817 3NK3NxCrwhkRQbC2dg7XFQkCxhgzzugcxwD2wtfq8dZXPuty78wQ
#   6818 3NLhNwiyZtJK7ov2JevZUB34W9NnmpiRZBzNvvR3yzVh5TRdGcWn
#   6819 3NL8kKqzWdEXUg2q4G6Qy7ir4A1PDNW5xFa5xE6hcKW7tQZVwUg8
#
# PREREQUISITES:
#   - mina-extract-blocks built (dune build src/app/extract_blocks)
#   - postgres reachable at localhost:5432 as superuser `postgres`/`postgres`
#   - rsync + ssh available if --upload-to-hetzner is set
#
# HETZNER UPLOAD TARGET:
#   /home/o1labs-generic/pvc-4d294645-6466-4260-b933-1b909ff9c3a1/test_data/archive_fork_canonical_bug

set -euo pipefail

PREFORK_DUMP=""
POSTFORK_DUMP=""
RUNTIME_CONFIG=""
OUTPUT_DIR=""
UPLOAD_TO_HETZNER=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefork-dump)    PREFORK_DUMP="$2"; shift 2 ;;
    --postfork-dump)   POSTFORK_DUMP="$2"; shift 2 ;;
    --runtime-config)  RUNTIME_CONFIG="$2"; shift 2 ;;
    --output)          OUTPUT_DIR="$2"; shift 2 ;;
    --upload-to-hetzner) UPLOAD_TO_HETZNER=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

for arg in PREFORK_DUMP POSTFORK_DUMP RUNTIME_CONFIG OUTPUT_DIR; do
  if [[ -z "${!arg}" ]]; then
    echo "missing --${arg,,/_/-}" >&2
    exit 1
  fi
done

mkdir -p "$OUTPUT_DIR"
scratch="$(mktemp -d -t stage-fork-bug-XXXXXX)"
trap 'rm -rf "$scratch"' EXIT

PGURI="postgres://postgres:postgres@localhost:5432"
EXTRACT_DB="archive_postfork_extract"

echo "[1/5] Restoring post-fork dump into $EXTRACT_DB"
psql "$PGURI/postgres" -c "DROP DATABASE IF EXISTS $EXTRACT_DB;"
psql "$PGURI/postgres" -c "DROP DATABASE IF EXISTS archive;"
mkdir -p "$scratch/postfork"
tar -xf "$POSTFORK_DUMP" -C "$scratch/postfork"
postfork_sql="$(ls "$scratch/postfork"/*.sql | head -1)"
# The dump hardcodes "archive" as its target db name. Apply it, then rename.
psql "$PGURI/postgres" -f "$postfork_sql"
psql "$PGURI/postgres" -c "ALTER DATABASE archive RENAME TO $EXTRACT_DB;"

echo "[2/5] Extracting chain B blocks 6816-6819 via mina-extract-blocks"
mkdir -p "$scratch/chain_b"
extract_bin="_build/default/src/app/extract_blocks/extract_blocks.exe"
if [[ ! -x "$extract_bin" ]]; then
  extract_bin="$(command -v mina-extract-blocks || true)"
fi
if [[ -z "$extract_bin" ]]; then
  echo "Error: mina-extract-blocks binary not found. Build with 'dune build src/app/extract_blocks' or install the package." >&2
  exit 1
fi

# Walk the subchain 6816 -> 6819 on chain B. start_from_specified follows
# parent links from end back to start, so this gives us 4 extensional JSONs
# in one shot.
chain_b_6816="3NL5YRUKggVqZaGazgNhbWMydcSJnPQtcu5PBfyEwbsHboynPMP1"
chain_b_6819="3NL8kKqzWdEXUg2q4G6Qy7ir4A1PDNW5xFa5xE6hcKW7tQZVwUg8"

"$extract_bin" \
  --archive-uri "$PGURI/$EXTRACT_DB" \
  --start-state-hash "$chain_b_6816" \
  --end-state-hash "$chain_b_6819" \
  --output-folder "$scratch/chain_b" \
  --include-block-height-in-name

echo "[3/5] Bundling chain B blocks into precomputed_blocks.tar.xz"
tar -cJf "$OUTPUT_DIR/precomputed_blocks.tar.xz" -C "$scratch/chain_b" .

echo "[4/5] Copying prefork dump + runtime config into $OUTPUT_DIR"
# Ensure the prefork dump is gzip-compressed (the test expects .sql.tar.gz).
if file --brief "$PREFORK_DUMP" | grep -q "gzip compressed"; then
  cp "$PREFORK_DUMP" "$OUTPUT_DIR/prefork_archive_dump.sql.tar.gz"
else
  gzip -c "$PREFORK_DUMP" > "$OUTPUT_DIR/prefork_archive_dump.sql.tar.gz"
fi
cp "$RUNTIME_CONFIG" "$OUTPUT_DIR/genesis.json"

# Cleanup scratch postgres db.
psql "$PGURI/postgres" -c "DROP DATABASE IF EXISTS $EXTRACT_DB;"

echo "[5/5] Fixture staged at $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"

if [[ "$UPLOAD_TO_HETZNER" -eq 1 ]]; then
  HETZNER_KEY="${HETZNER_KEY:-$HOME/work/secrets/storagebox.key}"
  HETZNER_USER="${HETZNER_USER:-u434410}"
  HETZNER_HOST="${HETZNER_HOST:-u434410-sub2.your-storagebox.de}"
  HETZNER_FIXTURE_PATH="${HETZNER_FIXTURE_PATH:-/home/o1labs-generic/pvc-4d294645-6466-4260-b933-1b909ff9c3a1/test_data/archive_fork_canonical_bug}"
  echo "Uploading to Hetzner $HETZNER_FIXTURE_PATH"
  rsync -avz --progress \
    -e "ssh -p 23 -i $HETZNER_KEY -o StrictHostKeyChecking=no" \
    "$OUTPUT_DIR/" "$HETZNER_USER@$HETZNER_HOST:$HETZNER_FIXTURE_PATH/"
fi

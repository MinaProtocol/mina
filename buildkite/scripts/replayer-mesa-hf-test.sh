#!/bin/bash

# test replayer on known archive db with mesa hard fork
set -euo pipefail

REPLAYER_APP=mina-replayer
PG_CONN=postgres://postgres:postgres@localhost:5432/archive
INPUT_FILE=src/test/archive/sample_mesa_hf_db/replayer-init.json
STOP_SLOT_CONFIG=src/test/archive/sample_mesa_hf_db/stop-slot-config.json
EXPECTED_OUTPUT=src/test/archive/sample_mesa_hf_db/expected-mesa-hf-replayer-output.json
OUTPUT_FILE=output.json

while [[ "$#" -gt 0 ]]; do case $1 in
  -a|--app) REPLAYER_APP="$2"; shift;;
  -p|--pg) PG_CONN="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

echo "Running replayer with mesa hard fork"
$REPLAYER_APP \
  --archive-uri "$PG_CONN" \
  --input-file "$INPUT_FILE" \
  --hard-fork-target mesa \
  --stop-slot-config-file "$STOP_SLOT_CONFIG" \
  --hard-fork-output-file "$OUTPUT_FILE" \
  --log-json \
  --log-level spam

echo "Comparing output to expected result"
# Ignore s3_data_hash: it is a SHA3-256 hash of the gzipped tar of the RocksDB
# ledger directory, which includes non-deterministic RocksDB metadata (timestamps,
# sequence numbers, compaction state) and gzip headers, so it may differ across runs
# even when the logical ledger contents are identical.
if diff <(jq -S 'del(.genesis_ledger.s3_data_hash)' "$OUTPUT_FILE") <(jq -S 'del(.genesis_ledger.s3_data_hash)' "$EXPECTED_OUTPUT"); then
  echo "SUCCEEDED: output matches expected result"
  exit 0
else
  echo "FAILED: output does not match expected result"
  exit 1
fi

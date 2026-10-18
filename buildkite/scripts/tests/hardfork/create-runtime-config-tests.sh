#!/bin/bash
#
# Tests for scripts/hardfork/create_runtime_config.sh.
#
# The script patches a fork config (new genesis timestamp + ledger hashes). The
# fork slot must be carried over verbatim from the fork config's
# proof.fork.global_slot_since_genesis -- it must NOT be recomputed from the
# wall-clock genesis window with a hard-coded slot time. The legacy code divided
# the window by 180 s/slot (Berkeley), which is wrong for a 90 s/slot Mesa
# prefork. See https://github.com/MinaProtocol/mina/issues/18980.

set -euo pipefail

# Resolve the repo root so the test can run from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CREATE_RUNTIME_CONFIG="$REPO_ROOT/scripts/hardfork/create_runtime_config.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required to run these tests" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
  echo "FAILED: $1"
  exit 1
}

# The authoritative fork slot, mirroring the mesa-mut fork block from #18980.
FORK_SLOT=458220
FORK_STATE_HASH="3NLfork000000000000000000000000000000000000000000000000fork"
FORK_BLOCKCHAIN_LENGTH=458

# Fork config to patch: carries the authoritative slot, state hash and length.
cat > "$WORK_DIR/fork_config.json" <<EOF
{
  "proof": {
    "fork": {
      "state_hash": "$FORK_STATE_HASH",
      "blockchain_length": $FORK_BLOCKCHAIN_LENGTH,
      "global_slot_since_genesis": $FORK_SLOT
    }
  },
  "epoch_data": {
    "staking": { "seed": "staking_seed" },
    "next": { "seed": "next_seed" }
  }
}
EOF

# Ledger hashes produced by runtime_genesis_ledger.
cat > "$WORK_DIR/hashes.json" <<EOF
{
  "ledger": { "hash": "ledger_hash", "s3_data_hash": "ledger_s3" },
  "epoch_data": {
    "staking": { "hash": "staking_hash", "s3_data_hash": "staking_s3" },
    "next": { "hash": "next_hash", "s3_data_hash": "next_s3" }
  }
}
EOF

# Prefork (base) config. If the buggy wall-clock recompute were ever
# reintroduced, it would use this prefork slot + the genesis window below and
# produce 455340 + 259200/180 = 456780 -- different from FORK_SLOT, so this test
# would catch the regression.
cat > "$WORK_DIR/prefork_config.json" <<EOF
{
  "genesis": { "genesis_state_timestamp": "2026-06-17T14:00:00Z" },
  "proof": { "fork": { "global_slot_since_genesis": 455340 } }
}
EOF

# A genesis timestamp 3 days (259200 s) after the prefork genesis -- the exact
# window from the failing run.
POSTFORK_TIMESTAMP="2026-06-20T14:00:00Z"

OUTPUT=$(
  FORK_CONFIG_JSON="$WORK_DIR/fork_config.json" \
    LEDGER_HASHES_JSON="$WORK_DIR/hashes.json" \
    FORKING_FROM_CONFIG_JSON="$WORK_DIR/prefork_config.json" \
    GENESIS_TIMESTAMP="$POSTFORK_TIMESTAMP" \
    SECONDS_PER_SLOT=180 \
    bash "$CREATE_RUNTIME_CONFIG"
)

echo "--- create_runtime_config.sh output:"
echo "$OUTPUT" | jq .

# 1. The fork slot is carried over verbatim (NOT 456780 from a 180 s/slot recompute).
actual_slot=$(echo "$OUTPUT" | jq -r '.proof.fork.global_slot_since_genesis')
[[ "$actual_slot" == "$FORK_SLOT" ]] ||
  fail "fork slot should be carried over verbatim ($FORK_SLOT), got $actual_slot (a 180 s/slot recompute would give 456780)"

# 2. state_hash and blockchain_length pass through from the fork config.
[[ "$(echo "$OUTPUT" | jq -r '.proof.fork.state_hash')" == "$FORK_STATE_HASH" ]] ||
  fail "state_hash not passed through"
[[ "$(echo "$OUTPUT" | jq -r '.proof.fork.blockchain_length')" == "$FORK_BLOCKCHAIN_LENGTH" ]] ||
  fail "blockchain_length not passed through"

# 3. The genesis timestamp is patched to the requested postfork value.
[[ "$(echo "$OUTPUT" | jq -r '.genesis.genesis_state_timestamp')" == "$POSTFORK_TIMESTAMP" ]] ||
  fail "genesis_state_timestamp not set to the requested value"

# 4. Ledger hashes come from the hashes file.
[[ "$(echo "$OUTPUT" | jq -r '.ledger.hash')" == "ledger_hash" ]] ||
  fail "ledger hash not taken from the hashes file"
[[ "$(echo "$OUTPUT" | jq -r '.epoch_data.staking.hash')" == "staking_hash" ]] ||
  fail "staking epoch hash not taken from the hashes file"

# 5. Independence from the slot-time constant: even an absurd SECONDS_PER_SLOT
#    must not change the carried-over slot.
OUTPUT_2=$(
  FORK_CONFIG_JSON="$WORK_DIR/fork_config.json" \
    LEDGER_HASHES_JSON="$WORK_DIR/hashes.json" \
    FORKING_FROM_CONFIG_JSON="$WORK_DIR/prefork_config.json" \
    GENESIS_TIMESTAMP="$POSTFORK_TIMESTAMP" \
    SECONDS_PER_SLOT=90 \
    bash "$CREATE_RUNTIME_CONFIG"
)
slot_2=$(echo "$OUTPUT_2" | jq -r '.proof.fork.global_slot_since_genesis')
[[ "$slot_2" == "$FORK_SLOT" ]] ||
  fail "fork slot must be independent of SECONDS_PER_SLOT, got $slot_2 with SECONDS_PER_SLOT=90"

echo "PASSED: fork slot is carried over verbatim and is independent of the slot-time constant"

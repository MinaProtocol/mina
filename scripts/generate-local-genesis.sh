#!/usr/bin/env bash

# Generate a minimal genesis ledger + runtime config with a fauceted account.
# Requires: mina binary (or nix to build it), jq
#
# Usage:
#   ./scripts/generate-local-genesis.sh --mina-binary /path/to/mina --output-dir /tmp/my-genesis
#
# If --mina-binary is not provided, builds via nix.
# Produces:
#   <output-dir>/faucet-key        (private key)
#   <output-dir>/faucet-key.pub    (public key)
#   <output-dir>/runtime_config.json

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Defaults
MINA_BINARY=""
RUNTIME_GENESIS_LEDGER_BINARY=""
OUTPUT_DIR="$PWD"
FAUCET_BALANCE="10000000"  # 10 billion mina (nanomina units used internally, but ledger format is whole MINA)
GENESIS_TIMESTAMP=""
NUM_EXTRA_ACCOUNTS=5
EXTRA_ACCOUNT_BALANCE="1000"

export MINA_PRIVKEY_PASS="${MINA_PRIVKEY_PASS:-}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --mina-binary)
      MINA_BINARY="$2"; shift 2 ;;
    --runtime-genesis-ledger-binary)
      RUNTIME_GENESIS_LEDGER_BINARY="$2"; shift 2 ;;
    --output-dir)
      OUTPUT_DIR="$2"; shift 2 ;;
    --faucet-balance)
      FAUCET_BALANCE="$2"; shift 2 ;;
    --timestamp)
      GENESIS_TIMESTAMP="$2"; shift 2 ;;
    --num-extra-accounts)
      NUM_EXTRA_ACCOUNTS="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--mina-binary PATH] [--runtime-genesis-ledger-binary PATH] [--output-dir DIR] [--faucet-balance MINA] [--timestamp ISO8601] [--num-extra-accounts N]"
      echo ""
      echo "Generates a keypair, a genesis ledger with a fauceted account, and a runtime_config.json."
      echo ""
      echo "  --faucet-balance    Balance in MINA for the faucet account (default: $FAUCET_BALANCE)"
      echo "  --num-extra-accounts  Number of dummy accounts to pad the ledger (default: $NUM_EXTRA_ACCOUNTS)"
      echo "  --timestamp         Genesis timestamp (default: 1 hour from now)"
      exit 0 ;;
    *)
      echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Dependencies
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required" >&2; exit 1
fi

# Default timestamp: 10 minutes ago (must be in the past for block production)
if [[ -z "$GENESIS_TIMESTAMP" ]]; then
  GENESIS_TIMESTAMP="$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ)"
fi

mkdir -p "$OUTPUT_DIR"

##########################################################
# 1. Ensure mina binary
##########################################################

if [[ -n "$MINA_BINARY" ]] && [[ -x "$MINA_BINARY" ]]; then
  echo "Using mina binary: $MINA_BINARY"
elif [[ -n "$MINA_BINARY" ]]; then
  echo "Error: mina binary not found or not executable: $MINA_BINARY" >&2; exit 1
else
  echo "Building mina via nix..."
  nix_result=$(nix build --no-link --print-out-paths "$(dirname "$SCRIPT_DIR")#devnet")
  MINA_BINARY="$nix_result/bin/mina"
  echo "Built mina: $MINA_BINARY"
fi

# Ensure runtime_genesis_ledger binary
if [[ -n "$RUNTIME_GENESIS_LEDGER_BINARY" ]] && [[ -x "$RUNTIME_GENESIS_LEDGER_BINARY" ]]; then
  echo "Using runtime_genesis_ledger binary: $RUNTIME_GENESIS_LEDGER_BINARY"
elif [[ -n "$RUNTIME_GENESIS_LEDGER_BINARY" ]]; then
  echo "Error: runtime_genesis_ledger binary not found or not executable: $RUNTIME_GENESIS_LEDGER_BINARY" >&2; exit 1
else
  echo "Building runtime_genesis_ledger via nix..."
  nix_result=$(nix build --no-link --print-out-paths "$(dirname "$SCRIPT_DIR")#devnet.genesis")
  RUNTIME_GENESIS_LEDGER_BINARY="$nix_result/bin/runtime_genesis_ledger"
  echo "Built runtime_genesis_ledger: $RUNTIME_GENESIS_LEDGER_BINARY"
fi

##########################################################
# 2. Generate faucet keypair
##########################################################

FAUCET_KEY_PATH="$OUTPUT_DIR/faucet-key"

if [[ -f "$FAUCET_KEY_PATH" ]] && [[ -f "${FAUCET_KEY_PATH}.pub" ]]; then
  echo "Faucet key already exists, skipping generation"
else
  echo "Generating faucet keypair..."
  "$MINA_BINARY" advanced generate-keypair --privkey-path "$FAUCET_KEY_PATH"
fi

FAUCET_PK=$(cat "${FAUCET_KEY_PATH}.pub")
echo "Faucet public key: $FAUCET_PK"

##########################################################
# 3. Build accounts list
##########################################################

# The compiled genesis winner key (hardcoded in src/lib/crypto/key_gen/sample_keypairs.ml,
# derived from private key EKFKgDtU3rcuFTVSEpmpXSkukjmX4cKefYREi6Sdsk7E7wsT7KRw).
# Must be in the ledger for genesis proof generation to work.
GENESIS_WINNER_PK="B62qiy32p8kAKnny8ZFwoMhYpBppM1DWVCqAPBYNcXnsAHhnfAAuXgg"

# Start with the genesis winner account and the faucet account
ACCOUNTS=$(jq -n \
  --arg winner "$GENESIS_WINNER_PK" \
  --arg pk "$FAUCET_PK" \
  --arg bal "$FAUCET_BALANCE" \
  '[
    { pk: $winner, balance: "1000", delegate: $winner },
    { pk: $pk, balance: $bal, delegate: $pk }
  ]')

# Add some dummy accounts so the ledger isn't trivially small.
# We generate deterministic-looking dummy keys by generating more keypairs.
for ((i=1; i<=NUM_EXTRA_ACCOUNTS; i++)); do
  EXTRA_KEY_PATH="$OUTPUT_DIR/extra-key-$i"
  if [[ -f "$EXTRA_KEY_PATH" ]] && [[ -f "${EXTRA_KEY_PATH}.pub" ]]; then
    : # already exists
  else
    "$MINA_BINARY" advanced generate-keypair --privkey-path "$EXTRA_KEY_PATH"
  fi
  EXTRA_PK=$(cat "${EXTRA_KEY_PATH}.pub")
  # Delegate all extras to the faucet so it can produce blocks
  ACCOUNTS=$(echo "$ACCOUNTS" | jq --arg pk "$EXTRA_PK" --arg bal "$EXTRA_ACCOUNT_BALANCE" --arg del "$FAUCET_PK" \
    '. + [{ pk: $pk, balance: $bal, delegate: $del }]')
done

echo "Total accounts in ledger: $(echo "$ACCOUNTS" | jq length)"

##########################################################
# 4. Build runtime_config_full.json with inline accounts
##########################################################

STAKING_SEED="2vahsgRV5nDPmtgr2Xo2Uq2dkngfSgvg7d1TKqQbY3wUS2ZDxCC3"
NEXT_SEED="2vbH4D8B76WMYPRFgeuVvdWVhv6tAFoCJtg83yuJT1dud3QVSiZn"

FULL_CONFIG=$(jq -n \
  --argjson accounts "$ACCOUNTS" \
  --arg staking_seed "$STAKING_SEED" \
  --arg next_seed "$NEXT_SEED" \
  '{
    ledger: {
      add_genesis_winner: false,
      accounts: $accounts
    },
    epoch_data: {
      staking: {
        seed: $staking_seed,
        accounts: $accounts
      },
      next: {
        seed: $next_seed,
        accounts: $accounts
      }
    }
  }')

FULL_CONFIG_PATH="$OUTPUT_DIR/runtime_config_full.json"
echo "$FULL_CONFIG" > "$FULL_CONFIG_PATH"
echo "Wrote $FULL_CONFIG_PATH"

##########################################################
# 5. Generate ledger hashes via runtime_genesis_ledger
##########################################################

GENESIS_DIR="$OUTPUT_DIR/genesis-ledger"
mkdir -p "$GENESIS_DIR"
HASHES_PATH="$OUTPUT_DIR/hashes.json"

echo "Generating ledger hashes..."
"$RUNTIME_GENESIS_LEDGER_BINARY" \
  --config-file "$FULL_CONFIG_PATH" \
  --hash-output-file "$HASHES_PATH" \
  --genesis-dir "$GENESIS_DIR" \
  --ignore-missing

##########################################################
# 6. Build final runtime_config.json (matches genesis_ledgers/*.json format)
##########################################################

RUNTIME_CONFIG=$(jq -n \
  --arg ts "$GENESIS_TIMESTAMP" \
  --arg staking_seed "$STAKING_SEED" \
  --arg next_seed "$NEXT_SEED" \
  --slurpfile hashes "$HASHES_PATH" \
  '
  {
    genesis: {
      genesis_state_timestamp: $ts
    },
    ledger: {
      add_genesis_winner: false
    },
    epoch_data: {
      staking: {
        seed: $staking_seed
      },
      next: {
        seed: $next_seed
      }
    }
  } * $hashes[0]
  ')

RUNTIME_CONFIG_PATH="$OUTPUT_DIR/runtime_config.json"
echo "$RUNTIME_CONFIG" > "$RUNTIME_CONFIG_PATH"

echo ""
echo "=== Done ==="
echo "  Faucet key:     $FAUCET_KEY_PATH"
echo "  Faucet pubkey:  $FAUCET_PK"
echo "  Faucet balance: $FAUCET_BALANCE MINA"
echo "  Runtime config: $RUNTIME_CONFIG_PATH"
echo "  Genesis dir:    $GENESIS_DIR"
echo ""
echo "To start a node:"
echo "  $MINA_BINARY daemon --config-file $RUNTIME_CONFIG_PATH --genesis-ledger-dir $GENESIS_DIR ..."

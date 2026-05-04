#!/bin/bash
# Offline-signer smoke test for the Rosetta integration suite.
#
# rosetta-cli's check:construction uses its own bundled Pallas signer from
# rosetta-sdk-go, so it does not exercise mina-ocaml-signer's signing path.
# The functions below drive /construction/* against the live online rosetta
# using mina-ocaml-signer as the offline signer and verify the resulting
# tx is accepted by the daemon and indexed by the archive.
#
# Usable in two modes:
#   * Sourced from another script: only defines functions, does nothing else.
#   * Executed directly: validates required env vars and runs the orchestrator
#     `offline_signer_smoke_test`.
#
# Required environment variables:
#   MINA_ROSETTA_ONLINE_PORT - port of the online rosetta instance
#   MINA_NETWORK             - network name used in network_identifier
#   PG_CONN                  - postgres connection string for the archive db
#   SNARK_PRODUCER_KEY       - path to the sender private-key file
#   SNARK_PRODUCER_PK        - sender public-key (address) string
#   BLOCK_PRODUCER_PUB_KEY   - receiver public-key (address) string

set -euo pipefail

# Default poll interval / progress logging knobs (overridable via env).
: "${OFFLINE_SIGNER_SMOKE_POLL_INTERVAL_SECS:=10}"
: "${OFFLINE_SIGNER_SMOKE_PROGRESS_EVERY_N_POLLS:=6}"
: "${OFFLINE_SIGNER_SMOKE_DEFAULT_TIMEOUT_SECS:=300}"

# Validate required env vars; exit 1 on the first missing one.
_offline_signer_smoke_require_env() {
  local required=(
    MINA_ROSETTA_ONLINE_PORT
    MINA_NETWORK
    PG_CONN
    SNARK_PRODUCER_KEY
    SNARK_PRODUCER_PK
    BLOCK_PRODUCER_PUB_KEY
  )
  local var
  for var in "${required[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      echo "offline-signer-smoke: required env var '${var}' is unset or empty" >&2
      exit 1
    fi
  done
}

# Lazy initialisers: computed once require_env has succeeded (or on first use).
_offline_signer_smoke_init() {
  rosetta_online="http://127.0.0.1:${MINA_ROSETTA_ONLINE_PORT}"
  network_id_json='{"blockchain":"mina","network":"'"${MINA_NETWORK}"'"}'
}

# POST a JSON body to a path on the online rosetta endpoint.
# Args: $1 endpoint path (e.g. /construction/metadata), $2 JSON body.
rosetta_post() {
  curl -sf -X POST "${rosetta_online}$1" \
    -H 'Content-Type: application/json' \
    -d "$2"
}

# Print the hex-encoded private key stored in the given mina key file.
# Args: $1 path to a mina private-key file.
signer_privkey_hex_of_file() {
  mina-ocaml-signer hex-of-private-key-file --private-key-path "$1"
}

# Derive the hex-encoded public key for a hex-encoded private key.
# Args: $1 hex-encoded private key.
#
# Note: `mina-ocaml-signer derive-public-key` prints metadata on lines 1-3
# and the hex public key on line 4. The `sed -n '4p'` parsing is fragile
# but matches the binary's current text output; if a structured output
# mode is added in the future, prefer that.
signer_pub_hex_of_privkey() {
  mina-ocaml-signer derive-public-key --private-key "$1" | sed -n '4p'
}

# Sign an unsigned transaction blob using a hex-encoded private key.
# Args: $1 hex-encoded private key, $2 unsigned transaction blob.
signer_sign_tx() {
  mina-ocaml-signer sign --private-key "$1" --unsigned-transaction "$2"
}

# Build the rosetta operations array for a simple MINA payment.
# Args: $1 sender address, $2 receiver address, $3 amount, $4 fee.
payment_ops_json() {
  jq -nc \
    --arg s "$1" --arg r "$2" --arg amt "$3" --arg fee "$4" '
    [ {operation_identifier:{index:0}, type:"fee_payment",
       account:{address:$s, metadata:{token_id:"1"}},
       amount:{value:("-"+$fee), currency:{symbol:"MINA", decimals:9}}}
    , {operation_identifier:{index:1}, type:"payment_source_dec",
       account:{address:$s, metadata:{token_id:"1"}},
       amount:{value:("-"+$amt), currency:{symbol:"MINA", decimals:9}}}
    , {operation_identifier:{index:2}, related_operations:[{index:1}],
       type:"payment_receiver_inc",
       account:{address:$r, metadata:{token_id:"1"}},
       amount:{value:$amt, currency:{symbol:"MINA", decimals:9}}}
    ]'
}

# Fetch the current nonce for a sender via /construction/metadata.
# Args: $1 sender address, $2 receiver address.
fetch_nonce() {
  rosetta_post /construction/metadata \
    "$(jq -nc --argjson nid "$network_id_json" --arg s "$1" --arg r "$2" '
      {network_identifier:$nid,
       options:{sender:$s, token_id:"1", receiver:$r},
       public_keys:[]}')" \
    | jq -r '.metadata.nonce'
}

# Fetch the unsigned transaction + signing payload via /construction/payloads.
# Args: $1 sender address, $2 receiver address, $3 nonce, $4 ops_json.
fetch_payloads() {
  rosetta_post /construction/payloads \
    "$(jq -nc --argjson nid "$network_id_json" --argjson ops "$4" \
              --arg s "$1" --arg r "$2" --arg n "$3" '
      {network_identifier:$nid,
       operations:$ops,
       metadata:{sender:$s, nonce:$n, token_id:"1", receiver:$r,
                 valid_until:"4294967295", memo:"offline-signer-smoke"},
       public_keys:[]}')"
}

# Combine the unsigned tx with a signature via /construction/combine.
# Args:
#   $1 unsigned transaction blob
#   $2 signing payload hex
#   $3 sender address
#   $4 sender public-key hex
#   $5 signature hex
# Prints the signed_transaction blob.
combine_signed_tx() {
  rosetta_post /construction/combine \
    "$(jq -nc --argjson nid "$network_id_json" \
              --arg un "$1" --arg sp "$2" --arg addr "$3" --arg pub "$4" --arg sig "$5" '
      {network_identifier:$nid,
       unsigned_transaction:$un,
       signatures:[{
         signing_payload:{hex_bytes:$sp,
                          account_identifier:{address:$addr},
                          signature_type:"schnorr_poseidon"},
         public_key:{hex_bytes:$pub, curve_type:"pallas"},
         signature_type:"schnorr_poseidon",
         hex_bytes:$sig}]}')" \
    | jq -r '.signed_transaction'
}

# Submit a signed transaction via /construction/submit.
# Args: $1 signed_transaction blob.
# Prints the resulting transaction hash.
submit_signed_tx() {
  rosetta_post /construction/submit \
    "$(jq -nc --argjson nid "$network_id_json" --arg stx "$1" '
      {network_identifier:$nid, signed_transaction:$stx}')" \
    | jq -r '.transaction_identifier.hash'
}

# Poll the archive db until the given tx hash appears in user_commands.
# Args: $1 tx hash, $2 (optional) timeout seconds (default
#                       OFFLINE_SIGNER_SMOKE_DEFAULT_TIMEOUT_SECS).
# Logs progress every OFFLINE_SIGNER_SMOKE_PROGRESS_EVERY_N_POLLS polls so
# the build log shows liveness.
wait_for_tx_in_archive() {
  local tx_hash="$1"
  local timeout_secs="${2:-${OFFLINE_SIGNER_SMOKE_DEFAULT_TIMEOUT_SECS}}"
  local poll_interval="${OFFLINE_SIGNER_SMOKE_POLL_INTERVAL_SECS}"
  local progress_every="${OFFLINE_SIGNER_SMOKE_PROGRESS_EVERY_N_POLLS}"
  local start_ts
  start_ts=$(date +%s)
  local deadline=$(( start_ts + timeout_secs ))
  local poll=0

  until psql "${PG_CONN}" -tAc "SELECT 1 FROM user_commands WHERE hash='${tx_hash}';" | grep -q 1; do
    if [[ $(date +%s) -ge ${deadline} ]]; then
      echo "FAIL: tx ${tx_hash} did not appear in archive within ${timeout_secs}s" >&2
      return 1
    fi
    poll=$(( poll + 1 ))
    if (( poll % progress_every == 0 )); then
      local elapsed=$(( $(date +%s) - start_ts ))
      echo "offline-signer-smoke: still waiting for tx ${tx_hash} (elapsed=${elapsed}s, timeout=${timeout_secs}s)"
    fi
    sleep "${poll_interval}"
  done
}

# Orchestrate the full offline-signer smoke test:
#   * derive sender pub from priv key
#   * fetch nonce + payloads from rosetta online
#   * sign offline using mina-ocaml-signer
#   * combine + submit via rosetta online
#   * wait for inclusion in the archive db
offline_signer_smoke_test() {
  _offline_signer_smoke_init

  local sender_key="${SNARK_PRODUCER_KEY}"
  local sender_addr="${SNARK_PRODUCER_PK}"
  local receiver_addr="${BLOCK_PRODUCER_PUB_KEY}"
  local amount=1000
  local fee=1000000000

  local sender_priv
  sender_priv=$(signer_privkey_hex_of_file "${sender_key}")
  local sender_pub_hex
  sender_pub_hex=$(signer_pub_hex_of_privkey "${sender_priv}")

  local nonce
  nonce=$(fetch_nonce "${sender_addr}" "${receiver_addr}")
  local ops
  ops=$(payment_ops_json "${sender_addr}" "${receiver_addr}" "${amount}" "${fee}")
  local payloads
  payloads=$(fetch_payloads "${sender_addr}" "${receiver_addr}" "${nonce}" "${ops}")

  local unsigned
  unsigned=$(echo "${payloads}" | jq -r '.unsigned_transaction')
  local sp_hex
  sp_hex=$(echo "${payloads}" | jq -r '.payloads[0].hex_bytes')

  local signature
  signature=$(signer_sign_tx "${sender_priv}" "${unsigned}")
  local signed
  signed=$(combine_signed_tx "${unsigned}" "${sp_hex}" "${sender_addr}" "${sender_pub_hex}" "${signature}")
  local tx_hash
  tx_hash=$(submit_signed_tx "${signed}")

  echo "offline-signer-smoke: submitted tx=${tx_hash}"
  wait_for_tx_in_archive "${tx_hash}" "${OFFLINE_SIGNER_SMOKE_DEFAULT_TIMEOUT_SECS}"
  echo "offline-signer-smoke: tx ${tx_hash} indexed in archive.user_commands"
}

# Only auto-run when executed directly (not when sourced).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _offline_signer_smoke_require_env
  offline_signer_smoke_test
fi

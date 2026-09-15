#!/bin/bash

# This script fetches a fork config from a running Mina node pod via its
# GraphQL endpoint, processes it, and uploads the result to GCS.
#
# The heavy lifting (jq extraction and gzip compression) happens on the pod
# to avoid transferring the full raw response (~640MB+). Only the compressed
# fork config is copied locally.
#
# The script is split into 5 resumable steps. If a step fails, fix the issue
# and re-run with --start-from N to skip already-completed steps. Intermediate
# files on the pod are preserved between runs to support this.
#
# Steps:
#   1. Fetch raw fork config via GraphQL (curl on pod)
#   2. Extract .data.fork_config and gzip (jq + gzip on pod)
#   3. Copy compressed file locally (with md5 verification and retries)
#   4. Validate JSON, rename to mesa-<block_length>-<state_hash>.json
#   5. Upload to GCS
#
# Prerequisites:
#   - kubectl configured and pointing at the right cluster
#   - KUBECONFIG env variable set (e.g. export KUBECONFIG=mesa_hf.json)
#   - jq, gzip, md5sum available locally
#   - gsutil configured for GCS access (step 5 only)
#   - The target pod must have curl, jq, and gzip installed
#
# Examples:
#   # Full run
#   export KUBECONFIG=mesa_hf.json
#   ./get_fork_config.sh --pod pre-mesa-whale-2-76c554dd6-pb4bm
#
#   # Resume from step 3 after fixing a download issue
#   ./get_fork_config.sh --pod pre-mesa-whale-2-76c554dd6-pb4bm --start-from 3
#
#   # Upload to a different GCS bucket
#   ./get_fork_config.sh --pod <pod> --gcs-bucket gs://my-bucket/path

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
# KUBECONFIG must be set by the caller (e.g. export KUBECONFIG=mesa_hf.json)
POD=""
GCS_BUCKET="${GCS_BUCKET:-gs://o1labs-gitops-infrastructure/mesa}"
GRAPHQL_TIMEOUT="${GRAPHQL_TIMEOUT:-600}"
START_FROM="${START_FROM:-1}"

# ── Colors & helpers ───────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

step_number=0

step() {
  step_number=$((step_number + 1))
  if [[ $step_number -lt $START_FROM ]]; then
    printf "${DIM}  [%d/5] %s … skipped${RESET}\n" "$step_number" "$1"
    return 1
  fi
  printf "\n${CYAN}${BOLD}  ▶ Step %d/5: %s${RESET}\n" "$step_number" "$1"
  return 0
}

ok()   { printf "${GREEN}    ✔ %s${RESET}\n" "$1"; }
fail() { printf "${RED}    ✘ %s${RESET}\n" "$1" >&2; exit 1; }
info() { printf "${DIM}    %s${RESET}\n" "$1"; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Fetch fork config from a Mina pod, process it, and upload to GCS.

Options:
  --pod NAME           Pod to query (required)
  --start-from STEP    Resume from step N (1-5, default: 1)
  --gcs-bucket URI     GCS destination (default: $GCS_BUCKET)

Environment:
  KUBECONFIG           Must be set by the caller before running this script
  -h, --help           Show this help

Steps:
  1  Fetch raw fork config (curl on pod)
  2  Extract & compress on pod (jq + gzip on pod)
  3  Copy compressed file locally
  4  Validate & rename
  5  Upload to GCS
EOF
  exit 0
}

# ── Parse arguments ────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pod)          POD="$2";             shift 2 ;;
    --start-from)   START_FROM="$2";      shift 2 ;;
    --gcs-bucket)   GCS_BUCKET="$2";      shift 2 ;;
    -h|--help)      usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

[[ -z "$POD" ]]        && fail "--pod is required"
[[ -z "${KUBECONFIG:-}" ]] && fail "KUBECONFIG env variable must be set"

printf "\n${BOLD}  Fork Config Fetcher${RESET}\n"
printf "  ─────────────────────────────────────\n"
info "Pod:        $POD"
info "Kubeconfig: $KUBECONFIG"
info "Start from: step $START_FROM"
printf "\n"

# ── Step 1: Fetch raw fork config on pod ───────────────────────────
if step "Fetch raw fork config on pod"; then
  kubectl exec "$POD" -- curl --silent --max-time "$GRAPHQL_TIMEOUT" --location \
    "http://localhost:3085/graphql" \
    --header "Content-Type: application/json" \
    --data '{"query":"query MyQuery { fork_config }","variables":{}}' \
    -o /tmp/raw_response.json \
    || fail "curl failed on pod"
  ok "Raw response saved to pod:/tmp/raw_response.json"
fi

# ── Step 2: Extract fork_config & compress on pod ──────────────────
if step "Extract & compress fork config on pod"; then
  kubectl exec "$POD" -- sh -c '
    jq -r ".data.fork_config" /tmp/raw_response.json > /tmp/fork_config.json \
      && jq empty /tmp/fork_config.json \
      && gzip -f /tmp/fork_config.json
  ' || fail "jq/gzip failed on pod"

  size=$(kubectl exec "$POD" -- stat -c%s /tmp/fork_config.json.gz 2>/dev/null || echo "unknown")
  ok "Compressed on pod: /tmp/fork_config.json.gz (${size} bytes)"
fi

# ── Step 3: Copy compressed file locally ───────────────────────────
if step "Copy compressed file locally"; then
  # Get expected md5 and size from pod
  remote_size=$(kubectl exec "$POD" -- stat -c%s /tmp/fork_config.json.gz 2>/dev/null) \
    || fail "File not found on pod"
  remote_md5=$(kubectl exec "$POD" -- md5sum /tmp/fork_config.json.gz | awk '{print $1}') \
    || fail "Failed to get remote checksum"
  info "Remote: ${remote_size} bytes, md5=${remote_md5}"

  # Download with retries and checksum verification
  # Use 'kubectl exec cat' instead of 'kubectl cp' to avoid tar-based
  # transfers that silently truncate large files.
  max_retries=3
  for attempt in $(seq 1 $max_retries); do
    info "Download attempt ${attempt}/${max_retries}..."
    kubectl exec "$POD" -- cat /tmp/fork_config.json.gz > fork_config.json.gz

    local_size=$(stat -c%s fork_config.json.gz 2>/dev/null || echo 0)
    local_md5=$(md5sum fork_config.json.gz 2>/dev/null | awk '{print $1}' || echo "none")

    if [[ "$local_md5" == "$remote_md5" ]]; then
      ok "Downloaded fork_config.json.gz (${local_size} bytes, md5 verified)"
      break
    fi

    if [[ "$attempt" -eq "$max_retries" ]]; then
      fail "Download failed after ${max_retries} attempts (local_md5=${local_md5} != remote_md5=${remote_md5})"
    fi
    info "Checksum mismatch, retrying..."
  done
fi

# ── Step 4: Validate & rename ──────────────────────────────────────
if step "Validate & rename"; then
  gunzip -k -f fork_config.json.gz
  jq empty fork_config.json || fail "Invalid JSON in fork_config.json"

  BLOCK_LENGTH=$(jq -r '.proof.fork.blockchain_length' fork_config.json)
  STATE_HASH=$(jq -r '.proof.fork.state_hash' fork_config.json)

  [[ -n "$BLOCK_LENGTH" && "$BLOCK_LENGTH" != "null" ]] || fail "Missing blockchain_length"
  [[ -n "$STATE_HASH"   && "$STATE_HASH"   != "null" ]] || fail "Missing state_hash"

  FORK_CONFIG_NAME="mesa-${BLOCK_LENGTH}-${STATE_HASH}.json"

  mv fork_config.json "$FORK_CONFIG_NAME"
  mv fork_config.json.gz "${FORK_CONFIG_NAME}.gz"

  ok "Name:             $FORK_CONFIG_NAME"
  info "Block length:     $BLOCK_LENGTH"
  info "State hash:       $STATE_HASH"
  info "Preview:          $(head -c 200 "$FORK_CONFIG_NAME")"
fi

# ── Step 5: Upload to GCS ─────────────────────────────────────────
if step "Upload to GCS"; then
  gsutil cp "${FORK_CONFIG_NAME}.gz" "$GCS_BUCKET/" \
    || fail "gsutil upload failed"
  ok "Uploaded ${FORK_CONFIG_NAME}.gz → $GCS_BUCKET/"
fi

# ── Summary ────────────────────────────────────────────────────────
printf "\n${GREEN}${BOLD}  ✔ Done!${RESET}\n"
printf "  ─────────────────────────────────────\n"
if [[ -n "${FORK_CONFIG_NAME:-}" ]]; then
  info "Local file: ${FORK_CONFIG_NAME}.gz"
  info "GCS:        ${GCS_BUCKET}/${FORK_CONFIG_NAME}.gz"
fi
printf "\n"

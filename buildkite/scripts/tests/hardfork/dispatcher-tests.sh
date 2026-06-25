#!/bin/bash
#
# Auto-Hardfork Dispatcher Tests
#
# This script validates that the mina-dispatch mechanism correctly switches
# between Berkeley and Mesa runtimes based on the activation state.
#
# The mina-dispatch script in auto-hardfork docker images checks for an
# activation marker file. When present, it runs the Mesa runtime; otherwise,
# it runs the Berkeley runtime.
#
# Tests:
#   1. Berkeley Runtime: Without activation marker, mina should use Berkeley
#      runtime (git commit differs from the expected Mesa commit)
#   2. Mesa Runtime: With activation marker, mina should use Mesa runtime
#      (git commit matches the expected Mesa commit)
#   3. Config Append: With activation marker, the dispatcher should keep user-provided
#      config file and append the hardfork-specific config as the last -config-file argument
#
# Usage:
#   ./dispatcher-test.sh --docker <image> [--git-commit <commit>] [--profile <profile>] [--network <network>]
#
# Arguments:
#   --docker      Required. Docker image to test
#   --git-commit  Optional. Expected Mesa git commit (defaults to current HEAD)
#   --profile     Optional. Profile name (default: devnet)
#   --network     Optional. Network name (default: mesa)
#

set -euox pipefail

# =============================================================================
# Configuration
# =============================================================================

DOCKER_IMAGE=""
PROFILE="devnet"
NETWORK="mesa"
GIT_COMMIT=""

# =============================================================================
# Helper Functions
# =============================================================================

# Activation marker path used by mina-dispatch to determine runtime
activation_marker_dir() {
  echo "/root/.mina-config/auto-fork-${NETWORK}-${PROFILE}"
}

# Create activation marker inside container
create_activation_marker() {
  local marker_dir
  marker_dir=$(activation_marker_dir)
  echo "mkdir -p ${marker_dir} && touch ${marker_dir}/activated"
}

# Run mina command in docker container
# Args: $1 - additional setup commands (optional)
run_mina_in_docker() {
  local setup_cmd="${1:-}"
  local full_cmd="${setup_cmd:+$setup_cmd && }mina --version"
  docker run --entrypoint bash "$DOCKER_IMAGE" -c "$full_cmd"
}

# Extract git commit from mina --version output
# Args: $1 - mina version output
extract_git_commit() {
  echo "$1" | awk '{print $2}'
}

# Validate git commit format (40+ hex characters)
# Args: $1 - commit string
validate_git_commit_format() {
  local commit="$1"
  if ! [[ "$commit" =~ ^[0-9a-f]{40,}$ ]]; then
    echo "Error: Invalid git commit format: $commit"
    exit 1
  fi
}

# Run mina-dispatch inside the image in JSON mode and capture the emitted JSON
# object into DISPATCH_JSON and the exit status into DISPATCH_STATUS. Stderr
# (INFO/DEBUG noise) is discarded so DISPATCH_JSON is a clean, parseable object.
#
# This lifts the repetitive `docker run --env ... --entrypoint bash ... ; STATUS=$?`
# block that every dispatch assertion below would otherwise duplicate.
#
# Args:
#   $1     - command line to run inside the container (e.g. "mina daemon --config-directory /x")
#   $2     - (optional) "marker" (default) to create the activation marker first
#            (mesa runtime), or "no-marker" to leave it absent (berkeley runtime)
#   $3..   - (optional) extra arguments inserted into `docker run` (e.g. --env KEY=VAL)
DISPATCH_JSON=""
DISPATCH_STATUS=0
run_dispatch_json() {
  local inner_cmd="$1"
  local marker_mode="${2:-marker}"
  # Drop the consumed positional args; the remainder are extra docker run args.
  if [[ $# -ge 2 ]]; then shift 2; else shift $#; fi

  local setup=""
  if [[ "$marker_mode" == "marker" ]]; then
    setup="$(create_activation_marker) && "
  fi

  set +e
  DISPATCH_JSON=$(docker run --env MINA_DISPATCHER_JSON=1 "$@" --entrypoint bash "$DOCKER_IMAGE" \
    -c "${setup}${inner_cmd}" 2>/dev/null)
  DISPATCH_STATUS=$?
  set -e
}

# Assert that jq filter $1 over DISPATCH_JSON produces a value containing $2.
assert_json_contains() {
  local filter="$1" needle="$2" actual
  actual=$(jq -r "$filter" <<< "$DISPATCH_JSON")
  if [[ "$actual" != *"$needle"* ]]; then
    echo "FAILED: expected '${filter}' to contain '${needle}'"
    echo "  Actual:    $actual"
    echo "  Full JSON: $DISPATCH_JSON"
    exit 1
  fi
}

# Assert that jq filter $1 over DISPATCH_JSON equals $2 exactly.
assert_json_eq() {
  local filter="$1" expected="$2" actual
  actual=$(jq -r "$filter" <<< "$DISPATCH_JSON")
  if [[ "$actual" != "$expected" ]]; then
    echo "FAILED: expected '${filter}' == '${expected}', got '${actual}'"
    echo "  Full JSON: $DISPATCH_JSON"
    exit 1
  fi
}

# Assert that the dispatcher exited non-zero (used for the error-path tests).
assert_dispatch_failed() {
  if [[ "$DISPATCH_STATUS" -eq 0 ]]; then
    echo "FAILED: expected non-zero exit, got 0"
    echo "  Full JSON: $DISPATCH_JSON"
    exit 1
  fi
}

# =============================================================================
# Argument Parsing
# =============================================================================

while [[ $# -gt 0 ]]; do
  case $1 in
    --docker)
      DOCKER_IMAGE="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --network)
      NETWORK="$2"
      shift 2
      ;;
    --git-commit)
      GIT_COMMIT="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# =============================================================================
# Validation
# =============================================================================

if [[ -z "$DOCKER_IMAGE" ]]; then
  echo "Error: --docker argument is required"
  exit 1
fi

# The JSON-mode assertions parse mina-dispatch output with jq.
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required to run these tests"
  exit 1
fi

if [[ -z "$GIT_COMMIT" ]]; then
  echo "Detecting current git commit..."
  GIT_COMMIT=$(git rev-parse HEAD)
  echo "Using git commit: $GIT_COMMIT"
fi

# =============================================================================
# Test 1: Berkeley Runtime (without activation marker)
# =============================================================================

echo ""
echo "=== Test 1: Berkeley Runtime ==="
echo "Running mina WITHOUT activation marker - should use Berkeley runtime"

if ! VERSION_OUTPUT=$(run_mina_in_docker ""); then
  echo "Error: Docker command failed"
  exit 1
fi

ACTUAL_COMMIT=$(extract_git_commit "$VERSION_OUTPUT")
validate_git_commit_format "$ACTUAL_COMMIT"

if [[ "$ACTUAL_COMMIT" == "$GIT_COMMIT" ]]; then
  echo "FAILED: Expected Berkeley runtime (different commit) but got Mesa runtime"
  echo "  Expected: commit != $GIT_COMMIT"
  echo "  Actual:   $ACTUAL_COMMIT"
  exit 1
fi

echo "PASSED: Got Berkeley runtime (commit: ${ACTUAL_COMMIT:0:12}...)"

# =============================================================================
# Test 2: Mesa Runtime (with activation marker)
# =============================================================================

echo ""
echo "=== Test 2: Mesa Runtime ==="
echo "Running mina WITH activation marker - should use Mesa runtime"

if ! VERSION_OUTPUT=$(run_mina_in_docker "$(create_activation_marker)"); then
  echo "Error: Docker command failed"
  exit 1
fi

ACTUAL_COMMIT=$(extract_git_commit "$VERSION_OUTPUT")
validate_git_commit_format "$ACTUAL_COMMIT"

if [[ "$ACTUAL_COMMIT" != "$GIT_COMMIT" ]]; then
  echo "FAILED: Expected Mesa runtime but got Berkeley runtime"
  echo "  Expected: $GIT_COMMIT"
  echo "  Actual:   $ACTUAL_COMMIT"
  exit 1
fi

echo "PASSED: Got Mesa runtime (commit: ${ACTUAL_COMMIT:0:12}...)"

# =============================================================================
# Test 3: Config Append (user config kept, hardfork config appended last)
# =============================================================================

echo ""
echo "=== Test 3: Config Append ==="
echo "Verifying that user-provided config is kept and hardfork config is appended as last -config-file"

run_dispatch_json "mina daemon -config-file /var/lib/coda/fake_config.json"

COMMAND=$(jq -r '.command' <<< "$DISPATCH_JSON")

# User's config file is still present, and the hardfork config is appended.
USER_CONFIG="-config-file /var/lib/coda/fake_config.json"
HARDFORK_CONFIG="-config-file $(activation_marker_dir)/daemon.json"
assert_json_contains '.command' "$USER_CONFIG"
assert_json_contains '.command' "$HARDFORK_CONFIG"

# Verify hardfork config appears AFTER user config (is the last -config-file).
USER_CONFIG_POS="${COMMAND%%"$USER_CONFIG"*}"
HARDFORK_CONFIG_POS="${COMMAND%%"$HARDFORK_CONFIG"*}"
if [[ ${#USER_CONFIG_POS} -ge ${#HARDFORK_CONFIG_POS} ]]; then
  echo "FAILED: Hardfork config should appear after user config"
  echo "  Command: $COMMAND"
  exit 1
fi

assert_json_contains '.command' "--genesis-ledger-dir $(activation_marker_dir)/genesis"

echo "PASSED: User config kept and hardfork config appended as last -config-file"

# =============================================================================
# Test 4: Genesis Ledger Override
# =============================================================================

echo ""
echo "=== Test 4: Genesis Ledger Override ==="
echo "Verifying that user-provided genesis ledger directory is overridden with hardfork ones"

run_dispatch_json "mina daemon --genesis-ledger-dir /var/lib/coda/fake/ledger"

# Genesis ledger dir overridden to mesa ledgers, and hardfork config appended
# even without a user-provided --config-file.
assert_json_contains '.command' "--genesis-ledger-dir $(activation_marker_dir)/genesis"
assert_json_contains '.command' "-config-file $(activation_marker_dir)/daemon.json"

echo "PASSED: Genesis ledger overridden and hardfork config appended"

# =============================================================================
# Test 5: Unsupported Subcommand Error
# =============================================================================

echo ""
echo "=== Test 5: Unsupported Subcommand ==="
echo "Verifying that dispatcher reports an error for non-daemon subcommands"

run_dispatch_json "mina accounts list" no-marker

assert_json_eq '.error' "unsupported_subcommand"
assert_dispatch_failed

echo "PASSED: Unsupported subcommand error is emitted"

# =============================================================================
# Test 6: MINA_HARDFORK_STATE_DIR Must Be Defined
# =============================================================================

echo ""
echo "=== Test 6: MINA_HARDFORK_STATE_DIR Required ==="
echo "Verifying that missing MINA_HARDFORK_STATE_DIR returns an error"

run_dispatch_json "mina --version" no-marker --env MINA_HARDFORK_STATE_DIR=

assert_json_eq '.error' "missing_hardfork_state_dir"
assert_dispatch_failed

echo "PASSED: Missing MINA_HARDFORK_STATE_DIR error is emitted"

# =============================================================================
# Test 7: Config Directory Must Match Hardfork State Dir
# =============================================================================

echo ""
echo "=== Test 7: Config Directory Validation ==="
echo "Verifying that --config-directory must match hardfork state directory"

run_dispatch_json "mina daemon --config-directory /var/lib/coda/fake"

assert_json_eq '.error' "config_directory_discrepancy"
# Error message should mention the required hardfork config directory.
assert_json_contains '.message' "/root/.mina-config"
assert_dispatch_failed

echo "PASSED: Mismatched --config-directory is rejected"

# =============================================================================
# Test 8: Client Subcommand Always Uses Mesa Runtime
# =============================================================================

echo ""
echo "=== Test 8: Client Subcommand Uses Mesa ==="
echo "Verifying that 'client status' always dispatches to mesa runtime"

# Without activation marker - client should still use mesa.
run_dispatch_json "mina client status" no-marker

assert_json_eq '.runtime' "mesa"
assert_json_contains '.command' "/mesa/mina client status"

echo "PASSED: client subcommand uses mesa runtime"

# =============================================================================
# Test 9: Config Directory Path Comparison (equivalent spellings accepted)
# =============================================================================

echo ""
echo "=== Test 9: Config Directory Path Comparison ==="
echo "Verifying that --config-directory equal to the hardfork state dir is accepted"
echo "even when written with a trailing slash or '.'/'..' segments"

# The hardfork state directory in the image (MINA_HARDFORK_STATE_DIR).
HARDFORK_STATE_DIR="/root/.mina-config"

# Each of these refers to the same directory as $HARDFORK_STATE_DIR and must
# therefore be accepted (no discrepancy error, dispatcher proceeds normally).
EQUIVALENT_DIRS=(
  "${HARDFORK_STATE_DIR}/"
  "${HARDFORK_STATE_DIR}/."
  "/root/../root/.mina-config"
)

for equivalent_dir in "${EQUIVALENT_DIRS[@]}"; do
  echo "--- Checking equivalent path: ${equivalent_dir}"

  run_dispatch_json "mina daemon --config-directory ${equivalent_dir}"

  # Equivalent path is accepted: the dispatcher succeeds (no error object) ...
  if [[ "$DISPATCH_STATUS" -ne 0 ]]; then
    echo "FAILED: Dispatcher exited non-zero for an equivalent --config-directory"
    echo "  Provided:  ${equivalent_dir}"
    echo "  Full JSON: $DISPATCH_JSON"
    exit 1
  fi
  assert_json_eq '.error // "none"' "none"
  # ... and the original (un-normalized) argument is passed through untouched.
  assert_json_contains '.command' "--config-directory ${equivalent_dir}"
done

echo "PASSED: Equivalent --config-directory spellings are accepted via path comparison"

# =============================================================================
# Test 10: Config Directory Path Comparison (genuine mismatch still rejected)
# =============================================================================

echo ""
echo "=== Test 10: Config Directory Genuine Mismatch ==="
echo "Verifying that a path resolving to a different directory is still rejected"

# This contains '..' but normalizes to a different directory, so it must error.
run_dispatch_json "mina daemon --config-directory /root/.mina-config/../other"

assert_json_eq '.error' "config_directory_discrepancy"
assert_dispatch_failed

echo "PASSED: Genuine path mismatch is still rejected"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=========================================="
echo "All tests passed!"
echo "=========================================="

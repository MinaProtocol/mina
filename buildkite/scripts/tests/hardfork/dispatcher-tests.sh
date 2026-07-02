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

# Modify mina-dispatch to echo the command instead of executing it
MINA_EXEC_COMMAND=$(docker run --env MINA_DISPATCHER_DRYRUN=1 --entrypoint bash "$DOCKER_IMAGE" \
  -c "$(create_activation_marker) && mina daemon -config-file /var/lib/coda/fake_config.json" 2>&1)

# Check user's config file is still present
USER_CONFIG="-config-file /var/lib/coda/fake_config.json"
if [[ "$MINA_EXEC_COMMAND" != *"$USER_CONFIG"* ]]; then
  echo "FAILED: User-provided config file was removed"
  echo "  Expected substring: $USER_CONFIG"
  echo "  Actual command: $MINA_EXEC_COMMAND"
  exit 1
fi

# Check hardfork config is appended
EXPECTED_CONFIG="-config-file $(activation_marker_dir)/daemon.json"
if [[ "$MINA_EXEC_COMMAND" != *"$EXPECTED_CONFIG"* ]]; then
  echo "FAILED: Hardfork config not appended"
  echo "  Expected substring: $EXPECTED_CONFIG"
  echo "  Actual command: $MINA_EXEC_COMMAND"
  exit 1
fi

# Verify hardfork config appears AFTER user config (is last -config-file)
USER_CONFIG_POS="${MINA_EXEC_COMMAND%%$USER_CONFIG*}"
HARDFORK_CONFIG_POS="${MINA_EXEC_COMMAND%%$EXPECTED_CONFIG*}"
if [[ ${#USER_CONFIG_POS} -ge ${#HARDFORK_CONFIG_POS} ]]; then
  echo "FAILED: Hardfork config should appear after user config"
  echo "  Actual command: $MINA_EXEC_COMMAND"
  exit 1
fi

if [[ "$MINA_EXEC_COMMAND" != *"--genesis-ledger-dir $(activation_marker_dir)/genesis"* ]]; then
  echo "FAILED: Genesis ledger directory not overridden to mesa-ledgers"
  echo "  Actual command: $MINA_EXEC_COMMAND"
  exit 1
fi

echo "PASSED: User config kept and hardfork config appended as last -config-file"

# =============================================================================
# Test 4: Genesis Ledger Override
# =============================================================================

echo ""
echo "=== Test 4: Genesis Ledger Override ==="
echo "Verifying that user-provided genesis ledger directory is overridden with hardfork ones"

MINA_EXEC_COMMAND=$(docker run --env MINA_DISPATCHER_DRYRUN=1 --entrypoint bash "$DOCKER_IMAGE" \
  -c "$(create_activation_marker) && mina daemon --genesis-ledger-dir /var/lib/coda/fake/ledger" 2>&1)

EXPECTED_CONFIG="--genesis-ledger-dir $(activation_marker_dir)/genesis"
if [[ "$MINA_EXEC_COMMAND" != *"$EXPECTED_CONFIG"* ]]; then
  echo "FAILED: Genesis ledger override not applied"
  echo "  Expected substring: $EXPECTED_CONFIG"
  echo "  Actual command: $MINA_EXEC_COMMAND"
  exit 1
fi

# Hardfork config should also be appended even without user-provided --config-file
EXPECTED_HF_CONFIG="-config-file $(activation_marker_dir)/daemon.json"
if [[ "$MINA_EXEC_COMMAND" != *"$EXPECTED_HF_CONFIG"* ]]; then
  echo "FAILED: Hardfork daemon config not appended"
  echo "  Expected substring: $EXPECTED_HF_CONFIG"
  echo "  Actual command: $MINA_EXEC_COMMAND"
  exit 1
fi

echo "PASSED: Genesis ledger overridden and hardfork config appended"

# =============================================================================
# Test 5: Unsupported Subcommand Error
# =============================================================================

echo ""
echo "=== Test 5: Unsupported Subcommand ==="
echo "Verifying that dispatcher reports an error for non-daemon subcommands"

set +e
MINA_EXEC_COMMAND=$(docker run --env MINA_DISPATCHER_DRYRUN=1 --entrypoint bash "$DOCKER_IMAGE" \
  -c "mina accounts list" 2>&1)
STATUS=$?
set -e

EXPECTED_ERROR="mina-dispatch ERROR: unsupported subcommand 'accounts'"
if [[ "$MINA_EXEC_COMMAND" != *"$EXPECTED_ERROR"* ]]; then
  echo "FAILED: Expected unsupported subcommand error"
  echo "  Expected substring: $EXPECTED_ERROR"
  echo "  Actual output: $MINA_EXEC_COMMAND"
  exit 1
fi

if [[ "$STATUS" -eq 0 ]]; then
  echo "FAILED: Expected non-zero exit for unsupported subcommand"
  exit 1
fi

echo "PASSED: Unsupported subcommand error is emitted"

# =============================================================================
# Test 6: MINA_HARDFORK_STATE_DIR Must Be Defined
# =============================================================================

echo ""
echo "=== Test 6: MINA_HARDFORK_STATE_DIR Required ==="
echo "Verifying that missing MINA_HARDFORK_STATE_DIR returns an error"

set +e
MINA_EXEC_COMMAND=$(docker run --env MINA_HARDFORK_STATE_DIR= --entrypoint bash "$DOCKER_IMAGE" \
  -c "mina --version" 2>&1)
STATUS=$?
set -e

EXPECTED_ERROR="mina-dispatch ERROR: MINA_HARDFORK_STATE_DIR is not defined"
if [[ "$MINA_EXEC_COMMAND" != *"$EXPECTED_ERROR"* ]]; then
  echo "FAILED: Expected missing MINA_HARDFORK_STATE_DIR error"
  echo "  Expected substring: $EXPECTED_ERROR"
  echo "  Actual output: $MINA_EXEC_COMMAND"
  exit 1
fi

if [[ "$STATUS" -eq 0 ]]; then
  echo "FAILED: Expected non-zero exit when MINA_HARDFORK_STATE_DIR is missing"
  exit 1
fi

echo "PASSED: Missing MINA_HARDFORK_STATE_DIR error is emitted"

# =============================================================================
# Test 7: Config Directory Must Match Hardfork State Dir
# =============================================================================

echo ""
echo "=== Test 7: Config Directory Validation ==="
echo "Verifying that --config-directory must match hardfork state directory"

set +e
MINA_EXEC_COMMAND=$(docker run --env MINA_DISPATCHER_DRYRUN=1 --entrypoint bash "$DOCKER_IMAGE" \
  -c "$(create_activation_marker) && mina daemon --config-directory /var/lib/coda/fake" 2>&1)
STATUS=$?
set -e

EXPECTED_ERROR="mina-dispatch ERROR: Discrepancy between provided --config-directory"
if [[ "$MINA_EXEC_COMMAND" != *"$EXPECTED_ERROR"* ]]; then
  echo "FAILED: Expected config directory validation error"
  echo "  Expected substring: $EXPECTED_ERROR"
  echo "  Actual output: $MINA_EXEC_COMMAND"
  exit 1
fi

EXPECTED_DIR="/root/.mina-config"
if [[ "$MINA_EXEC_COMMAND" != *"$EXPECTED_DIR"* ]]; then
  echo "FAILED: Expected error to mention required hardfork config directory"
  echo "  Expected substring: $EXPECTED_DIR"
  echo "  Actual output: $MINA_EXEC_COMMAND"
  exit 1
fi

if [[ "$STATUS" -eq 0 ]]; then
  echo "FAILED: Expected non-zero exit for mismatched --config-directory"
  exit 1
fi

echo "PASSED: Mismatched --config-directory is rejected"

# =============================================================================
# Test 8: Client Subcommand Always Uses Mesa Runtime
# =============================================================================

echo ""
echo "=== Test 8: Client Subcommand Uses Mesa ==="
echo "Verifying that 'client status' always dispatches to mesa runtime"

# Without activation marker - client should still use mesa
MINA_EXEC_COMMAND=$(docker run --env MINA_DISPATCHER_DRYRUN=1 --entrypoint bash "$DOCKER_IMAGE" \
  -c "mina client status" 2>&1)

if [[ "$MINA_EXEC_COMMAND" != *"/mesa/mina client status"* ]]; then
  echo "FAILED: client subcommand should use mesa runtime even without activation marker"
  echo "  Expected substring: /mesa/mina client status"
  echo "  Actual output: $MINA_EXEC_COMMAND"
  exit 1
fi

echo "PASSED: client subcommand uses mesa runtime"

# =============================================================================
# Test 9: Berkeley Daemon Always Runs In migrate-exit Mode
# =============================================================================

echo ""
echo "=== Test 9: Berkeley Daemon migrate-exit Injection ==="
echo "Verifying that the pre-fork (berkeley) daemon always gets --hardfork-handling migrate-exit"

# Without activation marker -> berkeley runtime
MINA_EXEC_COMMAND=$(docker run --env MINA_DISPATCHER_DRYRUN=1 --entrypoint bash "$DOCKER_IMAGE" \
  -c "mina daemon" 2>&1)

if [[ "$MINA_EXEC_COMMAND" != *"/berkeley/mina daemon"* ]]; then
  echo "FAILED: Expected berkeley runtime for daemon without activation marker"
  echo "  Actual command: $MINA_EXEC_COMMAND"
  exit 1
fi

if [[ "$MINA_EXEC_COMMAND" != *"--hardfork-handling migrate-exit"* ]]; then
  echo "FAILED: berkeley daemon should have --hardfork-handling migrate-exit injected"
  echo "  Actual command: $MINA_EXEC_COMMAND"
  exit 1
fi

echo "PASSED: berkeley daemon runs in migrate-exit mode"

# =============================================================================
# Test 10: Berkeley Daemon Respects User-Provided hardfork-handling
# =============================================================================

echo ""
echo "=== Test 10: Berkeley Daemon hardfork-handling Respected ==="
echo "Verifying that a user-provided --hardfork-handling value is left untouched"

MINA_EXEC_COMMAND=$(docker run --env MINA_DISPATCHER_DRYRUN=1 --entrypoint bash "$DOCKER_IMAGE" \
  -c "mina daemon --hardfork-handling keep-running" 2>&1)

if [[ "$MINA_EXEC_COMMAND" != *"--hardfork-handling keep-running"* ]]; then
  echo "FAILED: user-provided --hardfork-handling keep-running should be preserved"
  echo "  Actual command: $MINA_EXEC_COMMAND"
  exit 1
fi

if [[ "$MINA_EXEC_COMMAND" == *"--hardfork-handling migrate-exit"* ]]; then
  echo "FAILED: migrate-exit must not be injected when user provided their own value"
  echo "  Actual command: $MINA_EXEC_COMMAND"
  exit 1
fi

echo "PASSED: user-provided hardfork-handling left untouched"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=========================================="
echo "All tests passed!"
echo "=========================================="

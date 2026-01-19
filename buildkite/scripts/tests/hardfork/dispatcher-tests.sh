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
#   3. Config Override: With activation marker, the dispatcher should override
#      any user-provided config file with the hardfork-specific config
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

set -euo pipefail

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
    --help|-h)
      head -35 "$0" | tail -n +2 | sed 's/^# \?//'
      exit 0
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
  GIT_COMMIT=$(git rev-parse --long HEAD)
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
# Test 3: Config Override and Genesis Ledger Addition
# =============================================================================

echo ""
echo "=== Test 3: Config Override ==="
echo "Verifying that user-provided config is overridden with hardfork config"

# Modify mina-dispatch to echo the command instead of executing it
PATCH_DISPATCH="sed -i '\$s/^/echo /' /usr/local/bin/mina-dispatch"
SETUP_CMD="${PATCH_DISPATCH} && $(create_activation_marker)"

MINA_EXEC_COMMAND=$(docker run --entrypoint bash "$DOCKER_IMAGE" \
  -c "${SETUP_CMD} && mina daemon -config-file /var/lib/coda/fake_config.json")

EXPECTED_CONFIG="-config-file $(activation_marker_dir)/daemon.json"
if [[ "$MINA_EXEC_COMMAND" != *"$EXPECTED_CONFIG"* ]]; then
  echo "FAILED: Config override not applied"
  echo "  Expected substring: $EXPECTED_CONFIG"
  echo "  Actual command: $MINA_EXEC_COMMAND"
  exit 1
fi

if [[ "$MINA_EXEC_COMMAND" != *"--genesis-ledger-dir $(activation_marker_dir)/genesis"* ]]; then
  echo "FAILED: Genesis ledger directory not overridden to mesa-ledgers"
  echo "  Actual command: $MINA_EXEC_COMMAND"
  exit 1
fi

echo "PASSED: Config correctly overridden to hardfork config"

# =============================================================================
# Test 4: Config Override and Genesis Ledger Addition
# =============================================================================

echo ""
echo "=== Test 4: Config Override ==="
echo "Verifying that user-provided genesis ledger directory is overridden with hardfork ones"

# Modify mina-dispatch to echo the command instead of executing it
PATCH_DISPATCH="sed -i '\$s/^/echo /' /usr/local/bin/mina-dispatch"
SETUP_CMD="${PATCH_DISPATCH} && $(create_activation_marker)"

MINA_EXEC_COMMAND=$(docker run --entrypoint bash "$DOCKER_IMAGE" \
  -c "${SETUP_CMD} && mina daemon --genesis-ledger-dir /var/lib/coda/fake/ledger")

EXPECTED_CONFIG="--genesis-ledger-dir $(activation_marker_dir)/genesis"
if [[ "$MINA_EXEC_COMMAND" != *"$EXPECTED_CONFIG"* ]]; then
  echo "FAILED: Config override not applied"
  echo "  Expected substring: $EXPECTED_CONFIG"
  echo "  Actual command: $MINA_EXEC_COMMAND"
  exit 1
fi


echo "PASSED: Config correctly overridden to hardfork genesis ledgers"


# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=========================================="
echo "All tests passed!"
echo "=========================================="

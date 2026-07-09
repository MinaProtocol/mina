#!/bin/bash
# shellcheck disable=SC2034,SC2329  # nameref arrays/test fns are consumed indirectly by validate_unique_outputs/test dispatch
set -euo pipefail

################################################################################
# Test suite for parallel-build and duplicate-output detection in build.sh
#
# Usage:
#   bash scripts/debian/tests/test_build_parallel.sh
################################################################################

################################################################################
# Test Framework
################################################################################

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILURES=()
CURRENT_TEST=""

log_pass() { TESTS_PASSED=$((TESTS_PASSED + 1)); }

log_fail() {
  local msg="$1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILURES+=("${CURRENT_TEST}: ${msg}")
  echo "  FAIL: ${msg}" >&2
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    log_pass
  else
    log_fail "${label}: expected '${expected}', got '${actual}'"
  fi
}

assert_not_eq() {
  local label="$1" unexpected="$2" actual="$3"
  if [[ "$actual" != "$unexpected" ]]; then
    log_pass
  else
    log_fail "${label}: did NOT expect '${unexpected}'"
  fi
}

# Run a test function in a SUBSHELL so that any `exit` inside it (e.g. from
# validate_unique_outputs or build_deb) does not kill the test harness.
# Success / failure is determined solely by subshell exit code (0 = pass).
run_test_in_subshell() {
  local test_name="$1"
  CURRENT_TEST="$test_name"
  TESTS_RUN=$((TESTS_RUN + 1))

  echo -n "TEST: ${test_name} ... "

  local rc=0
  ( set -e; "$test_name" ) || rc=$?

  if [[ $rc -eq 0 ]]; then
    echo "OK"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAILED (exit code ${rc})"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILURES+=("${CURRENT_TEST}: subshell exited with code ${rc}")
  fi
}

# Run a simple assertion-based test directly (no subshell) so that
# log_pass / log_fail counts propagate.  Must NOT call exit internally.
run_test_direct() {
  local test_name="$1"
  CURRENT_TEST="$test_name"
  TESTS_RUN=$((TESTS_RUN + 1))
  local failures_before=${TESTS_FAILED}

  echo -n "TEST: ${test_name} ... "

  "$test_name" || true

  if [[ ${TESTS_FAILED} -eq ${failures_before} ]]; then
    echo "OK"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "FAILED"
  fi
}

################################################################################
# Setup
################################################################################

setup_parallel_test_env() {
  TEST_TMPDIR=$(mktemp -d)
  TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REAL_REPO_ROOT="$(git -C "${TEST_SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || echo "${TEST_SCRIPT_DIR}/../..")"
  REAL_SCRIPTS_DIR="${REAL_REPO_ROOT}/scripts/debian"

  # ---------- Mock git ----------
  MOCK_BIN_DIR="${TEST_TMPDIR}/mock_bin"
  mkdir -p "$MOCK_BIN_DIR"
  cat > "${MOCK_BIN_DIR}/git" << 'MOCKGIT'
#!/bin/bash
case "$*" in
  "fetch --tags --force"|"fetch --tags --prune --prune-tags --force") exit 0 ;;
  describe\ --always\ --abbrev=0*) echo "1.0.0" ;;
  "rev-parse --short=8 --verify HEAD") echo "abcd1234" ;;
  "rev-parse --short=8 "*) echo "fatal: ambiguous argument" >&2; exit 128 ;;
  name-rev\ --name-only*) echo "test-branch" ;;
  "tag --points-at HEAD") echo "" ;;
  "rev-parse --show-toplevel") echo "${PROJECT_ROOT}" ;;
  *) exit 0 ;;
esac
MOCKGIT
  chmod +x "${MOCK_BIN_DIR}/git"
  export PATH="${MOCK_BIN_DIR}:${PATH}"

  # ---------- Project directory ----------
  export PROJECT_ROOT="${TEST_TMPDIR}/project"
  mkdir -p "${PROJECT_ROOT}"
  export BUILD_DIR="${PROJECT_ROOT}/_build"
  mkdir -p "$BUILD_DIR"

  # ---------- Env vars required by builder-helpers.sh / build.sh ----------
  export SCRIPTPATH="${REAL_SCRIPTS_DIR}"
  export MINA_DEB_CODENAME="bullseye"
  export DUNE_PROFILE="devnet"
  export BRANCH_NAME="test-branch"
  export KEEP_MY_TAGS_INTACT=1
  export ARCHITECTURE="amd64"
  export MINA_DEB_RELEASE="unstable"
  export MINA_DEB_VERSION="1.0.0-test-branch-abcd123"
  unset DUNE_INSTRUMENT_WITH 2>/dev/null || true
  unset BUILD_DEB_CAPTURE_DIR 2>/dev/null || true

  # ---------- Source build.sh ----------
  # shellcheck disable=SC1090
  source "${REAL_SCRIPTS_DIR}/build.sh"

  echo "=== Parallel-build test environment ready. ==="
  echo "  DEB_SUFFIX=${DEB_SUFFIX:-<empty>}"
  echo "  MINA_ARCHIVE_DEB_NAME=${MINA_ARCHIVE_DEB_NAME}"
  echo "  POSTFORK_CODENAME=${POSTFORK_CODENAME}"
  echo ""
}

teardown_parallel_test_env() {
  rm -rf "$TEST_TMPDIR"
}

################################################################################
# Tests: resolve_deb_output correctness (no exit calls — run directly)
################################################################################

test_resolve_simple_tokens() {
  assert_eq "logproc"               "mina-logproc"            "$(resolve_deb_output logproc)"
  assert_eq "minimina"              "minimina"                "$(resolve_deb_output minimina)"
  assert_eq "tx_tools"              "mina-tx-tools"           "$(resolve_deb_output tx_tools)"
  assert_eq "test_executive"        "mina-test-executive"     "$(resolve_deb_output test_executive)"
  assert_eq "functional_test_suite" "mina-test-suite"         "$(resolve_deb_output functional_test_suite)"
  assert_eq "delegation_verify"     "mina-delegation-verify"  "$(resolve_deb_output delegation_verify)"
  assert_eq "daemon_storage_toolbox" "mina-daemon-storage-toolbox" "$(resolve_deb_output daemon_storage_toolbox)"
}

test_resolve_rosetta_tokens() {
  assert_eq "rosetta_generic" "mina-rosetta-generic"  "$(resolve_deb_output rosetta_generic)"
  assert_eq "rosetta_mainnet" "mina-rosetta-mainnet"  "$(resolve_deb_output rosetta_mainnet)"
  assert_eq "rosetta_devnet"  "mina-rosetta-devnet"   "$(resolve_deb_output rosetta_devnet)"
}

test_resolve_archive_tokens() {
  assert_eq "archive_generic" "mina-archive-generic"   "$(resolve_deb_output archive_generic)"
  assert_eq "archive_mainnet" "mina-archive-mainnet"   "$(resolve_deb_output archive_mainnet)"
  assert_eq "archive_devnet"  "${MINA_ARCHIVE_DEB_NAME}" "$(resolve_deb_output archive_devnet)"
}

test_resolve_daemon_tokens() {
  assert_eq "daemon_mainnet"              "mina-mainnet"              "$(resolve_deb_output daemon_mainnet)"
  assert_eq "daemon_devnet"               "mina-devnet"               "$(resolve_deb_output daemon_devnet)"
  assert_eq "daemon_mainnet_config"       "mina-mainnet-config"       "$(resolve_deb_output daemon_mainnet_config)"
  assert_eq "daemon_devnet_config"        "mina-devnet-config"        "$(resolve_deb_output daemon_devnet_config)"
  assert_eq "daemon_mainnet_hardfork_config" "mina-mainnet-config"    "$(resolve_deb_output daemon_mainnet_hardfork_config)"
  assert_eq "daemon_devnet_hardfork_config"  "mina-devnet-config"     "$(resolve_deb_output daemon_devnet_hardfork_config)"
  assert_eq "daemon_mainnet_prefork"   "mina-mainnet-prefork-mesa"   "$(resolve_deb_output daemon_mainnet_prefork)"
  assert_eq "daemon_devnet_prefork"    "mina-devnet-prefork-mesa"    "$(resolve_deb_output daemon_devnet_prefork)"
  assert_eq "daemon_mainnet_postfork"  "mina-mainnet-postfork-mesa"  "$(resolve_deb_output daemon_mainnet_postfork)"
  assert_eq "daemon_devnet_postfork"   "mina-devnet-postfork-mesa"   "$(resolve_deb_output daemon_devnet_postfork)"
  assert_eq "daemon_mainnet_automode"  "mina-mainnet-automode"       "$(resolve_deb_output daemon_mainnet_automode)"
  assert_eq "daemon_devnet_automode"   "mina-devnet-automode"        "$(resolve_deb_output daemon_devnet_automode)"
}

test_resolve_profile_tokens() {
  assert_eq "profile_mainnet"         "mina-mainnet-profile"  "$(resolve_deb_output profile_mainnet)"
  assert_eq "profile_devnet"          "mina-devnet-profile"   "$(resolve_deb_output profile_devnet)"
  assert_eq "profile_lightnet"        "mina-lightnet"         "$(resolve_deb_output profile_lightnet)"
  assert_eq "profile_dev"             "mina-dev"              "$(resolve_deb_output profile_dev)"
  assert_eq "profile_mainnet_generic" "mina-mainnet-generic"  "$(resolve_deb_output profile_mainnet_generic)"
  assert_eq "profile_devnet_generic"  "mina-devnet-generic"   "$(resolve_deb_output profile_devnet_generic)"
}

test_resolve_prefork_genesis_tokens() {
  assert_eq "prefork_mainnet_genesis_ledger" \
    "mina-create-mainnet-prefork-genesis-ledger" \
    "$(resolve_deb_output prefork_mainnet_genesis_ledger)"
  assert_eq "prefork_devnet_genesis_ledger" \
    "mina-create-devnet-prefork-genesis-ledger" \
    "$(resolve_deb_output prefork_devnet_genesis_ledger)"
}

################################################################################
# Tests: Duplicate output detection (may exit via validate_unique_outputs)
################################################################################

test_generic_tokens_produce_same_output() {
  local generic_out mainnet_out devnet_out
  generic_out=$(resolve_deb_output daemon_generic)
  mainnet_out=$(resolve_deb_output daemon_mainnet_generic)
  devnet_out=$(resolve_deb_output daemon_devnet_generic)
  assert_eq "canonical/mainnet generic produce same output" "$generic_out" "$mainnet_out"
  assert_eq "mainnet/devnet generic produce same output" "$mainnet_out" "$devnet_out"
}

test_config_and_hardfork_config_collide_mainnet() {
  local regular hf
  regular=$(resolve_deb_output daemon_mainnet_config)
  hf=$(resolve_deb_output daemon_mainnet_hardfork_config)
  assert_eq "mainnet config/hardfork_config collide" "$regular" "$hf"
}

test_config_and_hardfork_config_collide_devnet() {
  local regular hf
  regular=$(resolve_deb_output daemon_devnet_config)
  hf=$(resolve_deb_output daemon_devnet_hardfork_config)
  assert_eq "devnet config/hardfork_config collide" "$regular" "$hf"
}

test_distinct_tokens_produce_different_outputs() {
  local a b
  a=$(resolve_deb_output daemon_mainnet)
  b=$(resolve_deb_output daemon_devnet)
  assert_not_eq "mainnet/devnet daemon tents differ" "$a" "$b"
  a=$(resolve_deb_output rosetta_mainnet)
  b=$(resolve_deb_output rosetta_devnet)
  assert_not_eq "rosetta mainnet/devnet differ" "$a" "$b"
}

# validate_unique_outputs exits non-zero on duplicates.
# Run in a subshell via run_test_in_subshell.
test_validate_rejects_generic_duplicate() {
  local -a bad=("daemon_generic" "daemon_mainnet_generic")
  if validate_unique_outputs bad 2>/dev/null; then
    echo "FAIL: expected reject" >&2
    exit 1
  fi
}

test_validate_rejects_hardfork_config_duplicate() {
  local -a bad=("daemon_mainnet_config" "daemon_mainnet_hardfork_config")
  if validate_unique_outputs bad 2>/dev/null; then
    echo "FAIL: expected reject" >&2
    exit 1
  fi
}

test_validate_accepts_distinct_tokens() {
  local -a good=("logproc" "tx_tools" "daemon_mainnet" "archive_devnet")
  if ! validate_unique_outputs good; then
    echo "FAIL: expected acceptance" >&2
    exit 1
  fi
}

test_validate_rejects_unknown_token() {
  local -a bad=("totally_made_up_token")
  if validate_unique_outputs bad 2>/dev/null; then
    echo "FAIL: expected reject for unknown token" >&2
    exit 1
  fi
}

################################################################################
# Tests: MINA_DEB_JOBS=1 serial path with isolated BUILDDIRs
#         (build_deb may call exit 1 → run in subshell)
################################################################################

test_serial_build_with_isolated_builddir() {
  local app_dir="${BUILD_DIR}/default/src/app/logproc"
  mkdir -p "$app_dir"
  cat > "${app_dir}/logproc.exe" << 'EXE'
#!/bin/bash
exit 0
EXE
  chmod +x "${app_dir}/logproc.exe"

  mkdir -p "${PROJECT_ROOT}/genesis_ledgers"
  echo '{"genesis":"devnet"}' > "${PROJECT_ROOT}/genesis_ledgers/devnet.json"

  local capture_dir="${TEST_TMPDIR}/capture"
  mkdir -p "$capture_dir"
  export BUILD_DEB_CAPTURE_DIR="$capture_dir"
  export MINA_DEB_JOBS=1

  # main eventually calls build_deb which may exit; run in a subshell-caught block
  if main logproc; then
    :
  else
    echo "FAIL: main logproc failed" >&2
    exit 1
  fi

  if [[ -f "${capture_dir}/deb_name" ]]; then
    local captured_name
    captured_name=$(cat "${capture_dir}/deb_name")
    if [[ "$captured_name" != "mina-logproc" ]]; then
      echo "FAIL: captured deb name mismatch: ${captured_name}" >&2
      exit 1
    fi
  else
    echo "FAIL: capture did not produce deb_name" >&2
    exit 1
  fi
}

test_parallel_worker_output_is_buffered() {
  export MINA_DEB_JOBS=2

  resolve_deb_output() {
    case "$1" in
      alpha) echo "alpha-package" ;;
      beta) echo "beta-package" ;;
      *) return 1 ;;
    esac
  }

  resolve_and_build_package() {
    local token="$1"
    echo "${token}: start"
    case "$token" in
      alpha)
        sleep 0.2
        echo "${token}: end"
        ;;
      beta)
        sleep 0.05
        echo "${token}: end"
        ;;
      *)
        echo "unexpected token: ${token}" >&2
        return 1
        ;;
    esac
  }

  local output
  output=$(main alpha beta)

  if [[ "$output" != *"--- [worker:beta] output (exit 0)"*"beta: start"*"beta: end"*"--- [worker:beta] output end"* ]]; then
    echo "FAIL: beta worker output was not printed as one complete block" >&2
    echo "$output" >&2
    exit 1
  fi

  if [[ "$output" != *"--- [worker:alpha] output (exit 0)"*"alpha: start"*"alpha: end"*"--- [worker:alpha] output end"* ]]; then
    echo "FAIL: alpha worker output was not printed as one complete block" >&2
    echo "$output" >&2
    exit 1
  fi

  if [[ "$output" != *"--- [worker:beta] output end"*"--- [worker:alpha] output (exit 0)"* ]]; then
    echo "FAIL: worker logs were not printed when each worker exited" >&2
    echo "$output" >&2
    exit 1
  fi
}

################################################################################
# Tests: DEB_SUFFIX affects generic output name (no exit calls)
################################################################################

test_generic_output_with_lightnet_suffix() {
  local saved_suffix="${DEB_SUFFIX:-}"
  DEB_SUFFIX="lightnet"
  assert_eq "generic with lightnet suffix" \
    "mina-generic-lightnet" "$(resolve_deb_output daemon_generic)"
  assert_eq "generic with lightnet suffix (devnet token)" \
    "mina-generic-lightnet" "$(resolve_deb_output daemon_devnet_generic)"
  DEB_SUFFIX="${saved_suffix}"
}

test_generic_output_with_instrumented_suffix() {
  local saved_suffix="${DEB_SUFFIX:-}"
  DEB_SUFFIX="-instrumented"
  assert_eq "generic with -instrumented suffix" \
    "mina-generic-instrumented" "$(resolve_deb_output daemon_generic)"
  DEB_SUFFIX="${saved_suffix}"
}

################################################################################
# Tests: build_deb errors on pre-existing .deb (build_deb calls exit 1)
################################################################################

test_build_deb_errors_on_existing_deb() {
  local fake_deb="${BUILD_DIR}/mina-logproc_${MINA_DEB_VERSION}_${ARCHITECTURE}.deb"
  touch "$fake_deb"

  local app_dir="${BUILD_DIR}/default/src/app/logproc"
  mkdir -p "$app_dir"
  cat > "${app_dir}/logproc.exe" << 'EXE'
#!/bin/bash
exit 0
EXE
  chmod +x "${app_dir}/logproc.exe"

  mkdir -p "${PROJECT_ROOT}/genesis_ledgers"
  echo '{"genesis":"devnet"}' > "${PROJECT_ROOT}/genesis_ledgers/devnet.json"

  local worker_dir="${BUILD_DIR}/deb-build/logproc_existing_deb_test"
  mkdir -p "$worker_dir"
  export BUILDDIR="$worker_dir"

  if build_logproc_deb; then
    echo "FAIL: build_logproc_deb should have failed (pre-existing .deb)" >&2
    rm -f "$fake_deb" 2>/dev/null || true
    exit 1
  fi

  rm -f "$fake_deb" 2>/dev/null || true
}

################################################################################
# Main
################################################################################

main_tests() {
  echo "========================================"
  echo "build.sh parallel & duplicate-detection test suite"
  echo "========================================"
  echo ""

  setup_parallel_test_env

  # resolve_deb_output correctness (no exit calls)
  run_test_direct test_resolve_simple_tokens
  run_test_direct test_resolve_rosetta_tokens
  run_test_direct test_resolve_archive_tokens
  run_test_direct test_resolve_daemon_tokens
  run_test_direct test_resolve_profile_tokens
  run_test_direct test_resolve_prefork_genesis_tokens

  # Collision assertions
  run_test_direct test_generic_tokens_produce_same_output
  run_test_direct test_config_and_hardfork_config_collide_mainnet
  run_test_direct test_config_and_hardfork_config_collide_devnet
  run_test_direct test_distinct_tokens_produce_different_outputs

  # Validate duplicate rejection (may exit)
  run_test_in_subshell test_validate_rejects_generic_duplicate
  run_test_in_subshell test_validate_rejects_hardfork_config_duplicate
  run_test_in_subshell test_validate_accepts_distinct_tokens
  run_test_in_subshell test_validate_rejects_unknown_token

  # MINA_DEB_JOBS=1 serial path with isolated BUILDDIR
  # (build functions may call exit 1)
  run_test_in_subshell test_serial_build_with_isolated_builddir

  # MINA_DEB_JOBS>1 buffers each worker's output until that worker exits
  run_test_in_subshell test_parallel_worker_output_is_buffered

  # DEB_SUFFIX variants
  run_test_direct test_generic_output_with_lightnet_suffix
  run_test_direct test_generic_output_with_instrumented_suffix

  # build_deb memoization replaced with error (may exit)
  run_test_in_subshell test_build_deb_errors_on_existing_deb

  # Cleanup
  teardown_parallel_test_env

  # Report
  echo ""
  echo "========================================"
  echo "Results: ${TESTS_RUN} tests, ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
  echo "========================================"

  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo ""
    echo "Failures:"
    for f in "${FAILURES[@]}"; do
      echo "  - ${f}"
    done
  fi

  echo ""
  if [[ ${TESTS_FAILED} -gt 0 ]]; then
    exit 1
  else
    echo "All tests passed."
    exit 0
  fi
}

main_tests "$@"

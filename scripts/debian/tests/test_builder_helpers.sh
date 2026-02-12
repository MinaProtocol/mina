#!/bin/bash
set -euo pipefail

################################################################################
# Test suite for build_*_deb functions in builder-helpers.sh
#
# Usage:
#   bash scripts/debian/tests/test_builder_helpers.sh
#
# This test suite:
# - Creates a temporary directory with mock source files (executables, configs)
# - Mocks external tools (git, fakeroot, dpkg-deb)
# - Sources builder-helpers.sh in the mocked environment
# - Overrides build_deb() to capture the staging directory state to files
# - Runs each test in a subshell (to survive exit 1 from build functions)
# - Verifies each build_*_deb function produces correct package layout
################################################################################

################################################################################
# Test Framework
################################################################################

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

FAILURES=()
CURRENT_TEST=""

log_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

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

assert_contains() {
    local label="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        log_pass
    else
        log_fail "${label}: expected to contain '${needle}'"
    fi
}

assert_not_contains() {
    local label="$1" haystack="$2" needle="$3"
    if ! echo "$haystack" | grep -qF "$needle"; then
        log_pass
    else
        log_fail "${label}: should NOT contain '${needle}'"
    fi
}

assert_file_captured() {
    local path="$1"
    if echo "$CAPTURED_FILES" | grep -qF "./${path}"; then
        log_pass
    else
        log_fail "Expected file '${path}' in package"
    fi
}

assert_file_not_captured() {
    local path="$1"
    if ! echo "$CAPTURED_FILES" | grep -qF "./${path}"; then
        log_pass
    else
        log_fail "Unexpected file '${path}' in package"
    fi
}

assert_control_field() {
    local field="$1" expected="$2"
    local actual
    actual=$(echo "$CAPTURED_CONTROL" | grep "^${field}:" | head -1 | sed "s/^${field}: *//")
    if [[ "$actual" == "$expected" ]]; then
        log_pass
    else
        log_fail "Control '${field}': expected '${expected}', got '${actual}'"
    fi
}

assert_control_contains() {
    local field="$1" needle="$2"
    local line
    line=$(echo "$CAPTURED_CONTROL" | grep "^${field}:" | head -1 || true)
    if echo "$line" | grep -qF "$needle"; then
        log_pass
    else
        log_fail "Control '${field}' should contain '${needle}', got '${line}'"
    fi
}

assert_control_has_field() {
    local field="$1"
    if echo "$CAPTURED_CONTROL" | grep -q "^${field}:"; then
        log_pass
    else
        log_fail "Control file missing field '${field}'"
    fi
}

assert_control_no_field() {
    local field="$1"
    if ! echo "$CAPTURED_CONTROL" | grep -q "^${field}:"; then
        log_pass
    else
        log_fail "Control file should NOT have field '${field}'"
    fi
}

assert_captured_file_contains() {
    local path="$1" pattern="$2"
    local file="${CAPTURE_DIR}/last_build/${path}"
    if [[ -f "$file" ]] && grep -qF "$pattern" "$file"; then
        log_pass
    else
        log_fail "File '${path}' does not contain '${pattern}'"
    fi
}

# Shared assertions for common file sets

assert_common_daemon_binaries() {
    local root="${1:-usr/local/bin}"
    assert_file_captured "${root}/coda-libp2p_helper"
    assert_file_captured "${root}/mina-create-genesis"
    assert_file_captured "${root}/mina-generate-keypair"
    assert_file_captured "${root}/mina-validate-keypair"
    assert_file_captured "${root}/mina-standalone-snark-worker"
    assert_file_captured "${root}/mina-rocksdb-scanner"
    assert_file_captured "${root}/mina"
}

assert_daemon_utils() {
    assert_file_captured "usr/local/bin/mina-hf-create-runtime-config"
    assert_file_captured "usr/local/bin/mina-verify-packaged-fork-config"
    assert_file_captured "usr/lib/systemd/user/mina.service"
    assert_file_captured "etc/bash_completion.d/mina"
}

assert_archive_binaries() {
    assert_file_captured "usr/local/bin/mina-archive"
    assert_file_captured "usr/local/bin/mina-archive-blocks"
    assert_file_captured "usr/local/bin/mina-extract-blocks"
    assert_file_captured "usr/local/bin/mina-archive-hardfork-toolbox"
    assert_file_captured "usr/local/bin/mina-missing-blocks-guardian"
    assert_file_captured "usr/local/bin/mina-missing-blocks-auditor"
    assert_file_captured "usr/local/bin/mina-replayer"
}

assert_rosetta_binaries() {
    assert_file_captured "usr/local/bin/mina-rosetta"
    assert_file_captured "usr/local/bin/mina-ocaml-signer"
    assert_file_captured "usr/local/bin/mina-rosetta-indexer-test"
}

assert_rosetta_configs() {
    assert_file_captured "etc/mina/rosetta/scripts/run.sh"
    assert_file_captured "etc/mina/rosetta/rosetta-cli-config/config.json"
    assert_file_captured "etc/mina/rosetta/rosetta-cli-config/check.ros"
}

# Load captured state from files written by build_deb override
load_captured_state() {
    CAPTURED_DEB_NAME=""
    CAPTURED_CONTROL=""
    CAPTURED_FILES=""
    if [[ -f "${CAPTURE_DIR}/deb_name" ]]; then
        CAPTURED_DEB_NAME=$(cat "${CAPTURE_DIR}/deb_name")
    fi
    if [[ -f "${CAPTURE_DIR}/control" ]]; then
        CAPTURED_CONTROL=$(cat "${CAPTURE_DIR}/control")
    fi
    if [[ -f "${CAPTURE_DIR}/files" ]]; then
        CAPTURED_FILES=$(cat "${CAPTURE_DIR}/files")
    fi
}

# Run a build function safely in a subshell (protects against exit 1).
# Returns the exit code of the build function.
safe_build() {
    rm -f "${CAPTURE_DIR}/deb_name" "${CAPTURE_DIR}/control" "${CAPTURE_DIR}/files" 2>/dev/null || true
    rm -rf "${CAPTURE_DIR}/last_build" 2>/dev/null || true
    rm -rf "${BUILDDIR}" 2>/dev/null || true

    # NOTE: The subshell must NOT be followed by || true (or any || / &&),
    # because bash disables set -e inside subshells that are part of a
    # conditional list, making it impossible to detect build failures.
    # Callers (run_test, run_test_expect_fail) use set +e before invoking
    # test functions, so a non-zero exit here won't kill the script.
    (
        set -e
        "$@" > /dev/null 2>&1
    ) 2>/dev/null
    return $?
}

# Run a test function directly (NOT in a subshell).
# Test functions use safe_build() for build calls, then run assertions.
run_test() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    TESTS_RUN=$((TESTS_RUN + 1))
    local failures_before=${TESTS_FAILED}

    echo -n "TEST: ${test_name} ... "

    set +e
    "$test_name"
    set -e

    if [[ ${TESTS_FAILED} -eq ${failures_before} ]]; then
        echo "OK"
    else
        echo "FAILED"
    fi
}

# Run a test that is expected to fail (exit non-zero from build).
# Only checks the exit code, does not check captured state.
run_test_expect_fail() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    TESTS_RUN=$((TESTS_RUN + 1))

    echo -n "TEST: ${test_name} (expect fail) ... "

    local build_rc=0
    set +e
    "$test_name"
    build_rc=$?
    set -e

    if [[ $build_rc -ne 0 ]]; then
        log_pass  # Expected failure
        echo "OK (expected failure)"
    else
        log_fail "Expected failure but test succeeded"
        echo "FAILED"
    fi
}

################################################################################
# Setup
################################################################################

setup_test_environment() {
    TEST_TMPDIR=$(mktemp -d)
    export PROJECT_ROOT="${TEST_TMPDIR}/project"

    # Determine real repo paths
    TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REAL_REPO_ROOT="$(cd "${TEST_SCRIPT_DIR}/../../.." && pwd)"
    REAL_SCRIPTS_DIR="${REAL_REPO_ROOT}/scripts/debian"

    #---------------------------------------------------------------------------
    # Create mock git binary
    #---------------------------------------------------------------------------
    MOCK_BIN_DIR="${TEST_TMPDIR}/mock_bin"
    mkdir -p "$MOCK_BIN_DIR"

    cat > "${MOCK_BIN_DIR}/git" << 'MOCKGIT'
#!/bin/bash
case "$*" in
    "fetch --tags --force"|"fetch --tags --prune --prune-tags --force")
        exit 0 ;;
    describe\ --always\ --abbrev=0*)
        echo "1.0.0" ;;
    "rev-parse --short=8 --verify HEAD")
        echo "abcd1234" ;;
    name-rev\ --name-only*)
        echo "test-branch" ;;
    "tag --points-at HEAD")
        echo "" ;;
    "rev-parse --show-toplevel")
        echo "${PROJECT_ROOT}" ;;
    *)
        exit 0 ;;
esac
MOCKGIT
    chmod +x "${MOCK_BIN_DIR}/git"

    # Mock fakeroot: just execute the command
    cat > "${MOCK_BIN_DIR}/fakeroot" << 'EOF'
#!/bin/bash
"$@"
EOF
    chmod +x "${MOCK_BIN_DIR}/fakeroot"

    # Mock dpkg-deb: create a dummy .deb file
    cat > "${MOCK_BIN_DIR}/dpkg-deb" << 'EOF'
#!/bin/bash
# Last argument is the output file
touch "${@: -1}" 2>/dev/null || true
EOF
    chmod +x "${MOCK_BIN_DIR}/dpkg-deb"

    export PATH="${MOCK_BIN_DIR}:${PATH}"

    #---------------------------------------------------------------------------
    # Create project directory structure with mock source files
    #---------------------------------------------------------------------------
    export BUILD_DIR="${PROJECT_ROOT}/_build"
    mkdir -p "$BUILD_DIR"

    # Helper: create a mock executable
    create_mock_exe() {
        local path="$1"
        mkdir -p "$(dirname "${BUILD_DIR}/${path}")"
        cat > "${BUILD_DIR}/${path}" << 'MOCKEXE'
#!/bin/bash
if [[ "${COMMAND_OUTPUT_INSTALLATION_BASH:-}" == "1" ]]; then
    echo "# mock bash completion for mina"
    exit 0
fi
echo "mock binary"
MOCKEXE
        chmod +x "${BUILD_DIR}/${path}"
    }

    # All .exe files referenced by builder-helpers.sh (relative to BUILD_DIR)
    create_mock_exe "default/src/app/logproc/logproc.exe"
    create_mock_exe "default/src/app/test_executive/test_executive.exe"
    create_mock_exe "default/src/app/batch_txn_tool/batch_txn_tool.exe"
    create_mock_exe "default/src/test/command_line_tests/command_line_tests.exe"
    create_mock_exe "default/src/app/benchmarks/benchmarks.exe"
    create_mock_exe "default/src/app/ledger_export_bench/ledger_export_benchmark.exe"
    create_mock_exe "default/src/app/disk_caching_stats/disk_caching_stats.exe"
    create_mock_exe "default/src/app/heap_usage/heap_usage.exe"
    create_mock_exe "default/src/app/zkapp_limits/zkapp_limits.exe"
    create_mock_exe "default/src/test/archive/patch_archive_test/patch_archive_test.exe"
    create_mock_exe "default/src/test/archive/archive_node_tests/archive_node_tests.exe"
    create_mock_exe "default/src/app/rosetta/rosetta_mainnet_signatures.exe"
    create_mock_exe "default/src/app/rosetta/rosetta_testnet_signatures.exe"
    create_mock_exe "default/src/app/rosetta/ocaml-signer/signer_mainnet_signatures.exe"
    create_mock_exe "default/src/app/rosetta/ocaml-signer/signer_testnet_signatures.exe"
    create_mock_exe "default/src/app/rosetta/indexer_test/indexer_test.exe"
    create_mock_exe "default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe"
    create_mock_exe "default/src/app/generate_keypair/generate_keypair.exe"
    create_mock_exe "default/src/app/validate_keypair/validate_keypair.exe"
    create_mock_exe "default/src/lib/snark_worker/standalone/run_snark_worker.exe"
    create_mock_exe "default/src/app/rocksdb-scanner/rocksdb_scanner.exe"
    create_mock_exe "default/src/app/cli/src/mina_mainnet_signatures.exe"
    create_mock_exe "default/src/app/cli/src/mina_testnet_signatures.exe"
    create_mock_exe "default/src/app/archive/archive.exe"
    create_mock_exe "default/src/app/archive_blocks/archive_blocks.exe"
    create_mock_exe "default/src/app/extract_blocks/extract_blocks.exe"
    create_mock_exe "default/src/app/archive_hardfork_toolbox/archive_hardfork_toolbox.exe"
    create_mock_exe "default/src/app/missing_blocks_auditor/missing_blocks_auditor.exe"
    create_mock_exe "default/src/app/replayer/replayer.exe"
    create_mock_exe "default/src/app/zkapp_test_transaction/zkapp_test_transaction.exe"
    create_mock_exe "default/src/app/delegation_verify/delegation_verify.exe"

    #---------------------------------------------------------------------------
    # Source files under PROJECT_ROOT (referenced via ../ from BUILD_DIR)
    #---------------------------------------------------------------------------

    # libp2p_helper
    mkdir -p "${PROJECT_ROOT}/src/app/libp2p_helper/result/bin"
    echo "mock-libp2p" > "${PROJECT_ROOT}/src/app/libp2p_helper/result/bin/libp2p_helper"
    chmod +x "${PROJECT_ROOT}/src/app/libp2p_helper/result/bin/libp2p_helper"

    # hardfork scripts
    mkdir -p "${PROJECT_ROOT}/scripts/hardfork"
    echo "#!/bin/bash" > "${PROJECT_ROOT}/scripts/hardfork/create_runtime_config.sh"
    echo "#!/bin/bash" > "${PROJECT_ROOT}/scripts/hardfork/mina-verify-packaged-fork-config"
    chmod +x "${PROJECT_ROOT}/scripts/hardfork/create_runtime_config.sh"
    chmod +x "${PROJECT_ROOT}/scripts/hardfork/mina-verify-packaged-fork-config"

    # archive scripts
    mkdir -p "${PROJECT_ROOT}/scripts/archive"
    echo "#!/bin/bash" > "${PROJECT_ROOT}/scripts/archive/missing-blocks-guardian.sh"
    chmod +x "${PROJECT_ROOT}/scripts/archive/missing-blocks-guardian.sh"

    # systemd service template
    mkdir -p "${PROJECT_ROOT}/scripts"
    cat > "${PROJECT_ROOT}/scripts/mina.service" << 'SVCEOF'
[Unit]
Description=Mina Daemon Service
After=network.target

[Service]
Environment="PEERS_LIST_URL=PEERS_LIST_URL_PLACEHOLDER"
Environment="LOG_LEVEL=Info"
Type=simple
ExecStart=/usr/local/bin/mina daemon

[Install]
WantedBy=default.target
SVCEOF

    # genesis ledgers
    mkdir -p "${PROJECT_ROOT}/genesis_ledgers"
    echo '{"genesis": "mainnet"}' > "${PROJECT_ROOT}/genesis_ledgers/mainnet.json"
    echo '{"genesis": "devnet"}' > "${PROJECT_ROOT}/genesis_ledgers/devnet.json"

    # rosetta scripts and configs
    mkdir -p "${PROJECT_ROOT}/src/app/rosetta/scripts"
    echo "#!/bin/bash" > "${PROJECT_ROOT}/src/app/rosetta/scripts/run.sh"

    mkdir -p "${PROJECT_ROOT}/src/app/rosetta/rosetta-cli-config"
    echo '{}' > "${PROJECT_ROOT}/src/app/rosetta/rosetta-cli-config/config.json"
    echo 'ros-data' > "${PROJECT_ROOT}/src/app/rosetta/rosetta-cli-config/check.ros"

    # archive SQL files
    mkdir -p "${PROJECT_ROOT}/src/app/archive"
    echo "CREATE TABLE test;" > "${PROJECT_ROOT}/src/app/archive/create_schema.sql"
    echo "ALTER TABLE test;" > "${PROJECT_ROOT}/src/app/archive/migrations.sql"

    # test archive files
    mkdir -p "${PROJECT_ROOT}/src/test/archive/sample_db"
    echo "test-data" > "${PROJECT_ROOT}/src/test/archive/sample_db/data.txt"
    echo "archive-test-file" > "${PROJECT_ROOT}/src/test/archive/test_config.txt"

    # delegation verify scripts
    mkdir -p "${PROJECT_ROOT}/src/app/delegation_verify/scripts"
    echo "#!/bin/bash" > "${PROJECT_ROOT}/src/app/delegation_verify/scripts/authenticate.sh"

    # hardfork runtime config and ledger tarballs (for hardfork tests)
    echo '{"fork": true}' > "${TEST_TMPDIR}/fork_config.json"
    echo "ledger-data-1" > "${TEST_TMPDIR}/ledger1.tar.gz"
    echo "ledger-data-2" > "${TEST_TMPDIR}/ledger2.tar.gz"

    #---------------------------------------------------------------------------
    # Create capture directory
    #---------------------------------------------------------------------------
    CAPTURE_DIR="${TEST_TMPDIR}/captures"
    mkdir -p "$CAPTURE_DIR"
    export CAPTURE_DIR

    #---------------------------------------------------------------------------
    # Set environment variables
    #---------------------------------------------------------------------------
    export MINA_DEB_CODENAME="bullseye"
    export MINA_DEB_RELEASE="unstable"
    export ARCHITECTURE="amd64"
    export DUNE_PROFILE="devnet"
    export KEEP_MY_TAGS_INTACT=1
    export BRANCH_NAME="test-branch"
    unset DUNE_INSTRUMENT_WITH 2>/dev/null || true

    #---------------------------------------------------------------------------
    # Create modified builder-helpers.sh with fixed SCRIPTPATH
    #---------------------------------------------------------------------------
    MODIFIED_SCRIPT="${TEST_TMPDIR}/builder-helpers-modified.sh"
    sed "s|^SCRIPTPATH=.*|SCRIPTPATH=\"${REAL_SCRIPTS_DIR}\"|" \
        "${REAL_SCRIPTS_DIR}/builder-helpers.sh" > "$MODIFIED_SCRIPT"

    #---------------------------------------------------------------------------
    # Source builder-helpers.sh (changes CWD to BUILD_DIR, sets up variables)
    #---------------------------------------------------------------------------
    source "$MODIFIED_SCRIPT"

    # Store expected values set by export-git-env-vars.sh via our mock git
    export EXPECTED_VERSION="${MINA_DEB_VERSION}"       # 1.0.0-test-branch-abcd123
    export EXPECTED_GITHASH_CONFIG="${GITHASH_CONFIG}"   # abcd1234

    #---------------------------------------------------------------------------
    # Override build_deb to capture staging directory state to files
    #---------------------------------------------------------------------------
    build_deb() {
        echo "${1}" > "${CAPTURE_DIR}/deb_name"
        cat "${BUILDDIR}/DEBIAN/control" > "${CAPTURE_DIR}/control" 2>/dev/null || true
        (cd "${BUILDDIR}" && find . -type f | sort) > "${CAPTURE_DIR}/files"

        # Save a copy for content inspection
        rm -rf "${CAPTURE_DIR}/last_build"
        cp -a "${BUILDDIR}" "${CAPTURE_DIR}/last_build"

        # Clean up like the original
        rm -rf "${BUILDDIR}"
    }

    echo "Environment ready. MINA_DEB_VERSION=${MINA_DEB_VERSION}"
    echo ""
}

teardown_test_environment() {
    rm -rf "$TEST_TMPDIR"
}

################################################################################
# Tests: Simple single-binary packages
################################################################################

test_build_logproc_deb() {
    safe_build build_logproc_deb || { log_fail "build exited non-zero"; return; }
    load_captured_state
    assert_eq "deb name" "mina-logproc" "$CAPTURED_DEB_NAME"

    # Control file
    assert_control_field "Package" "mina-logproc"
    assert_control_contains "Depends" "libssl1.1"
    assert_control_contains "Depends" "libgmp10"
    assert_control_contains "Depends" "libgomp1"
    assert_control_contains "Depends" "tzdata"
    assert_control_contains "Depends" "liblmdb0"
    assert_control_no_field "Suggests"
    assert_control_no_field "Replaces"

    # Files
    assert_file_captured "usr/local/bin/mina-logproc"
    assert_file_captured "DEBIAN/control"
}

test_build_test_executive_deb() {
    safe_build build_test_executive_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-test-executive" "$CAPTURED_DEB_NAME"

    assert_control_field "Package" "mina-test-executive"
    assert_control_contains "Depends" "libssl1.1"
    assert_control_contains "Depends" "mina-logproc"
    assert_control_contains "Depends" "python3"
    assert_control_contains "Depends" "docker-ce"

    assert_file_captured "usr/local/bin/mina-test-executive"
}

test_build_batch_txn_deb() {
    safe_build build_batch_txn_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-batch-txn" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-batch-txn"
    assert_control_contains "Depends" "libssl1.1"

    assert_file_captured "usr/local/bin/mina-batch-txn"
}

################################################################################
# Tests: Multi-binary packages
################################################################################

test_build_functional_test_suite_deb() {
    safe_build build_functional_test_suite_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-test-suite" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-test-suite"

    # Test binaries
    assert_file_captured "usr/local/bin/mina-command-line-tests"
    assert_file_captured "usr/local/bin/mina-benchmarks"
    assert_file_captured "usr/local/bin/mina-ledger-export-benchmark"
    assert_file_captured "usr/local/bin/mina-disk-caching-stats"
    assert_file_captured "usr/local/bin/mina-heap-usage"
    assert_file_captured "usr/local/bin/mina-zkapp-limits"
    assert_file_captured "usr/local/bin/mina-patch-archive-test"
    assert_file_captured "usr/local/bin/mina-archive-node-test"

    # Archive test data (copied via cp -r and rsync)
    assert_file_captured "etc/mina/test/archive/test_config.txt"
    assert_file_captured "etc/mina/test/archive/sample_db/data.txt"
}

################################################################################
# Tests: Rosetta packages
################################################################################

test_build_rosetta_mainnet_deb() {
    safe_build build_rosetta_mainnet_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-rosetta-mainnet" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-rosetta-mainnet"
    assert_control_contains "Depends" "libssl1.1"
    assert_control_contains "Suggests" "jq"
    assert_control_contains "Suggests" "curl"

    assert_rosetta_binaries
    assert_rosetta_configs
}

test_build_rosetta_devnet_deb() {
    safe_build build_rosetta_devnet_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-rosetta-devnet" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-rosetta-devnet"
    assert_control_contains "Suggests" "jq"

    assert_rosetta_binaries
    assert_rosetta_configs
}

test_build_rosetta_testnet_generic_deb() {
    safe_build build_rosetta_testnet_generic_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-rosetta-testnet-generic" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-rosetta-testnet-generic"
    assert_control_contains "Suggests" "jq"

    assert_rosetta_binaries
    assert_rosetta_configs
}

################################################################################
# Tests: Daemon packages
################################################################################

test_build_daemon_mainnet_deb() {
    safe_build build_daemon_mainnet_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-mainnet" "$CAPTURED_DEB_NAME"

    # Control file
    assert_control_field "Package" "mina-mainnet"
    assert_control_contains "Depends" "libssl1.1"
    assert_control_contains "Depends" "libffi7"
    assert_control_contains "Depends" "libjemalloc2"
    assert_control_contains "Depends" "mina-logproc"
    assert_control_contains "Depends" "mina-mainnet-config"
    assert_control_contains "Suggests" "jq"
    assert_control_contains "Replaces" "mina-mainnet"
    assert_control_has_field "Breaks"

    # Daemon binaries (mainnet signatures)
    assert_common_daemon_binaries
    # Daemon utils
    assert_daemon_utils

    # Verify service file has mainnet seed URL
    assert_captured_file_contains \
        "usr/lib/systemd/user/mina.service" \
        "https://storage.googleapis.com/mina-seed-lists/mainnet_seeds.txt"

    # Bash completion was generated
    assert_captured_file_contains "etc/bash_completion.d/mina" "mock bash completion"
}

test_build_daemon_mainnet_config_deb() {
    safe_build build_daemon_mainnet_config_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-mainnet-config" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-mainnet-config"

    # Config-only package: no Depends on libraries
    assert_control_no_field "Depends"
    assert_control_contains "Suggests" "jq"
    assert_control_has_field "Replaces"
    assert_control_has_field "Breaks"

    # Genesis ledger files
    assert_file_captured "var/lib/coda/config_${EXPECTED_GITHASH_CONFIG}.json"
    assert_file_captured "var/lib/coda/mainnet.json"

    # Should NOT have binaries
    assert_file_not_captured "usr/local/bin/mina"

    # Verify genesis content
    assert_captured_file_contains "var/lib/coda/mainnet.json" "mainnet"
}

test_build_daemon_devnet_deb() {
    safe_build build_daemon_devnet_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-devnet" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-devnet"
    assert_control_contains "Depends" "mina-devnet-config"
    assert_control_contains "Depends" "mina-logproc"
    assert_control_contains "Suggests" "jq"
    assert_control_contains "Replaces" "mina-devnet"

    assert_common_daemon_binaries
    assert_daemon_utils

    # Verify devnet seed URL in service file
    assert_captured_file_contains \
        "usr/lib/systemd/user/mina.service" \
        "https://storage.googleapis.com/seed-lists/devnet_seeds.txt"
}

test_build_daemon_devnet_config_deb() {
    safe_build build_daemon_devnet_config_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-devnet-config" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-devnet-config"
    assert_control_no_field "Depends"

    assert_file_captured "var/lib/coda/config_${EXPECTED_GITHASH_CONFIG}.json"
    assert_file_captured "var/lib/coda/devnet.json"
    assert_file_not_captured "usr/local/bin/mina"

    assert_captured_file_contains "var/lib/coda/devnet.json" "devnet"
}

################################################################################
# Tests: Pre-hardfork (legacy) packages
################################################################################

test_build_daemon_mainnet_pre_hardfork_deb() {
    safe_build build_daemon_mainnet_pre_hardfork_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-mainnet-pre-hardfork-mesa" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-mainnet-pre-hardfork-mesa"
    assert_control_contains "Depends" "libssl1.1"
    assert_control_contains "Suggests" "jq"

    # Binaries in alternate directory (for automode)
    assert_common_daemon_binaries "usr/lib/mina/bin/berkeley"

    # Should NOT have binaries in default location
    assert_file_not_captured "usr/local/bin/mina"
    # Should NOT have config files
    assert_file_not_captured "var/lib/coda/mainnet.json"
    # Should NOT have service file
    assert_file_not_captured "usr/lib/systemd/user/mina.service"
}

test_build_daemon_devnet_pre_hardfork_deb() {
    safe_build build_daemon_devnet_pre_hardfork_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-devnet-pre-hardfork-mesa" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-devnet-pre-hardfork-mesa"
    assert_control_contains "Depends" "libssl1.1"

    # Binaries in alternate directory
    assert_common_daemon_binaries "usr/lib/mina/bin/berkeley"
    assert_file_not_captured "usr/local/bin/mina"
}

################################################################################
# Tests: Testnet Generic package
################################################################################

test_build_daemon_testnet_generic_deb() {
    safe_build build_daemon_testnet_generic_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    # Default name (no lightnet, no instrumentation)
    assert_eq "deb name" "mina-testnet-generic" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-testnet-generic"
    assert_control_contains "Depends" "libssl1.1"
    assert_control_contains "Depends" "mina-logproc"
    assert_control_contains "Suggests" "jq"
    assert_control_contains "Replaces" "mina-devnet"

    assert_common_daemon_binaries
    assert_daemon_utils

    # testnet-generic gets devnet.json but NOT as magic config
    assert_file_captured "var/lib/coda/devnet.json"
    assert_file_not_captured "var/lib/coda/config_${EXPECTED_GITHASH_CONFIG}.json"
}

################################################################################
# Tests: Archive packages
################################################################################

test_build_archive_devnet_deb() {
    safe_build build_archive_devnet_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-archive-devnet" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-archive-devnet"
    assert_control_contains "Depends" "libssl1.1"
    assert_control_contains "Depends" "libpq-dev"
    assert_control_contains "Depends" "libjemalloc2"
    # Archive packages should NOT depend on DAEMON_DEPS
    assert_not_contains "archive deps no libffi" "$CAPTURED_CONTROL" "libffi"

    assert_archive_binaries
    # SQL migration scripts
    assert_file_captured "etc/mina/archive/create_schema.sql"
    assert_file_captured "etc/mina/archive/migrations.sql"
}

test_build_archive_testnet_generic_deb() {
    safe_build build_archive_testnet_generic_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    # Default name (no suffix)
    assert_eq "deb name" "mina-archive-testnet-generic" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-archive-testnet-generic"
    assert_control_contains "Depends" "libpq-dev"

    assert_archive_binaries
    assert_file_captured "etc/mina/archive/create_schema.sql"
}

test_build_archive_mainnet_deb() {
    safe_build build_archive_mainnet_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-archive-mainnet" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-archive-mainnet"
    assert_control_contains "Depends" "libpq-dev"

    assert_archive_binaries
    assert_file_captured "etc/mina/archive/create_schema.sql"
    assert_file_captured "etc/mina/archive/migrations.sql"
}

################################################################################
# Tests: Hardfork config packages
################################################################################

test_build_daemon_devnet_hardfork_config_deb() {
    # Set required hardfork env vars
    export RUNTIME_CONFIG_JSON="${TEST_TMPDIR}/fork_config.json"
    export LEDGER_TARBALLS="${TEST_TMPDIR}/ledger1.tar.gz ${TEST_TMPDIR}/ledger2.tar.gz"

    safe_build build_daemon_devnet_hardfork_config_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-devnet-config" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-devnet-config"
    assert_control_no_field "Depends"

    # Hardfork runtime config replaces the standard one
    assert_file_captured "var/lib/coda/config_${EXPECTED_GITHASH_CONFIG}.json"
    assert_captured_file_contains \
        "var/lib/coda/config_${EXPECTED_GITHASH_CONFIG}.json" '{"fork": true}'

    # Ledger tarballs copied
    assert_file_captured "var/lib/coda/ledger1.tar.gz"
    assert_file_captured "var/lib/coda/ledger2.tar.gz"

    # Old genesis ledger backup
    assert_file_captured "var/lib/coda/devnet.old.json"
    assert_captured_file_contains "var/lib/coda/devnet.old.json" "devnet"

    # devnet.json replaced with fork config
    assert_file_captured "var/lib/coda/devnet.json"
    assert_captured_file_contains "var/lib/coda/devnet.json" '{"fork": true}'

    unset RUNTIME_CONFIG_JSON LEDGER_TARBALLS
}

# This test documents a BUG: build_daemon_testnet_generic_hardfork_config_deb
# passes "berkeley" to copy_common_daemon_hardfork_configs, which calls
# copy_common_daemon_configs("berkeley"). That function does not recognize
# "berkeley" as a valid network name and calls exit 1.
test_build_daemon_testnet_generic_hardfork_config_deb_fails() {
    export RUNTIME_CONFIG_JSON="${TEST_TMPDIR}/fork_config.json"
    export LEDGER_TARBALLS="${TEST_TMPDIR}/ledger1.tar.gz"

    safe_build build_daemon_testnet_generic_hardfork_config_deb
    local rc=$?

    unset RUNTIME_CONFIG_JSON LEDGER_TARBALLS
    return $rc
}

test_build_daemon_mainnet_hardfork_config_deb() {
    export RUNTIME_CONFIG_JSON="${TEST_TMPDIR}/fork_config.json"
    export LEDGER_TARBALLS="${TEST_TMPDIR}/ledger1.tar.gz ${TEST_TMPDIR}/ledger2.tar.gz"

    safe_build build_daemon_mainnet_hardfork_config_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-mainnet-config" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-mainnet-config"
    assert_control_no_field "Depends"
    assert_control_contains "Replaces" "mina-mainnet"

    assert_file_captured "var/lib/coda/config_${EXPECTED_GITHASH_CONFIG}.json"
    assert_captured_file_contains \
        "var/lib/coda/config_${EXPECTED_GITHASH_CONFIG}.json" '{"fork": true}'

    assert_file_captured "var/lib/coda/ledger1.tar.gz"
    assert_file_captured "var/lib/coda/ledger2.tar.gz"

    assert_file_captured "var/lib/coda/mainnet.old.json"
    assert_captured_file_contains "var/lib/coda/mainnet.old.json" "mainnet"

    assert_file_captured "var/lib/coda/mainnet.json"
    assert_captured_file_contains "var/lib/coda/mainnet.json" '{"fork": true}'

    unset RUNTIME_CONFIG_JSON LEDGER_TARBALLS
}

################################################################################
# Tests: Utility packages
################################################################################

test_build_zkapp_test_transaction_deb() {
    safe_build build_zkapp_test_transaction_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-zkapp-test-transaction" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-zkapp-test-transaction"
    assert_control_contains "Depends" "libssl1.1"
    assert_control_contains "Depends" "libffi7"
    assert_control_no_field "Suggests"

    assert_file_captured "usr/local/bin/mina-zkapp-test-transaction"
}

test_build_delegation_verify_deb() {
    safe_build build_delegation_verify_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-delegation-verify" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-delegation-verify"
    assert_control_contains "Depends" "libssl1.1"

    assert_file_captured "usr/local/bin/mina-delegation-verify"
    assert_file_captured "etc/mina/aws/authenticate.sh"
}

test_build_create_legacy_genesis_deb() {
    safe_build build_create_legacy_genesis_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-create-legacy-genesis" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-create-legacy-genesis"
    assert_control_contains "Depends" "libssl1.1"

    assert_file_captured "usr/local/bin/mina-create-legacy-genesis"
}

################################################################################
# Tests: Naming variants (lightnet, instrumented)
################################################################################

test_build_daemon_devnet_lightnet_naming() {
    # Simulate lightnet profile naming
    local saved_name="${MINA_DEVNET_DEB_NAME}"
    MINA_DEVNET_DEB_NAME="mina-devnet-lightnet"

    safe_build build_daemon_devnet_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-devnet-lightnet" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-devnet-lightnet"

    MINA_DEVNET_DEB_NAME="${saved_name}"
}

test_build_daemon_testnet_generic_lightnet_naming() {
    local saved_name="${MINA_DEB_NAME}"
    MINA_DEB_NAME="mina-testnet-generic-lightnet"

    safe_build build_daemon_testnet_generic_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-testnet-generic-lightnet" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-testnet-generic-lightnet"

    MINA_DEB_NAME="${saved_name}"
}

test_build_archive_testnet_generic_suffix_naming() {
    local saved_suffix="${DEB_SUFFIX}"
    DEB_SUFFIX="-lightnet"

    safe_build build_archive_testnet_generic_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-archive-testnet-generic-lightnet" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-archive-testnet-generic-lightnet"

    DEB_SUFFIX="${saved_suffix}"
}

test_build_daemon_devnet_instrumented_naming() {
    local saved_name="${MINA_DEVNET_DEB_NAME}"
    MINA_DEVNET_DEB_NAME="mina-devnet-instrumented"

    safe_build build_daemon_devnet_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_eq "deb name" "mina-devnet-instrumented" "$CAPTURED_DEB_NAME"
    assert_control_field "Package" "mina-devnet-instrumented"

    MINA_DEVNET_DEB_NAME="${saved_name}"
}

################################################################################
# Tests: Codename-specific dependencies
################################################################################

test_codename_noble_deps() {
    # Save current deps
    local saved_shared="${SHARED_DEPS}"
    local saved_daemon="${DAEMON_DEPS}"
    local saved_archive="${ARCHIVE_DEPS}"

    # Simulate noble codename deps
    SHARED_DEPS="libssl3t64, libgmp10, libgomp1, tzdata, liblmdb0"
    DAEMON_DEPS=", libffi8, libjemalloc2, libpq-dev, libproc2-0, mina-logproc"
    ARCHIVE_DEPS="libssl3t64, libgomp1, libpq-dev, libjemalloc2"

    safe_build build_logproc_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_control_contains "Depends" "libssl3t64"
    assert_not_contains "noble should not have libssl1.1" "$CAPTURED_CONTROL" "libssl1.1"

    # Restore
    SHARED_DEPS="${saved_shared}"
    DAEMON_DEPS="${saved_daemon}"
    ARCHIVE_DEPS="${saved_archive}"
}

test_codename_noble_archive_deps() {
    local saved_archive="${ARCHIVE_DEPS}"
    ARCHIVE_DEPS="libssl3t64, libgomp1, libpq-dev, libjemalloc2"

    safe_build build_archive_devnet_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_control_contains "Depends" "libssl3t64"

    ARCHIVE_DEPS="${saved_archive}"
}

################################################################################
# Tests: Control file structure
################################################################################

test_control_file_common_fields() {
    safe_build build_logproc_deb || { log_fail "build exited non-zero"; return; }

    load_captured_state
    assert_control_field "Version" "${EXPECTED_VERSION}"
    assert_control_field "Architecture" "amd64"
    assert_control_field "License" "Apache-2.0"
    assert_control_field "Origin" "MinaProtocol"
    assert_control_field "Label" "MinaProtocol"
    assert_control_field "Codename" "bullseye"
    assert_control_field "Suite" "unstable"
    assert_control_field "Section" "base"
    assert_control_field "Priority" "optional"
    assert_contains "control has description" "$CAPTURED_CONTROL" "Description:"
    assert_contains "control has git hash" "$CAPTURED_CONTROL" "${GITHASH}"
}

################################################################################
# Main
################################################################################

main() {
    echo "========================================"
    echo "builder-helpers.sh test suite"
    echo "========================================"
    echo ""

    setup_test_environment

    # Simple packages
    run_test test_build_logproc_deb
    run_test test_build_test_executive_deb
    run_test test_build_batch_txn_deb

    # Multi-binary packages
    run_test test_build_functional_test_suite_deb

    # Rosetta packages
    run_test test_build_rosetta_mainnet_deb
    run_test test_build_rosetta_devnet_deb
    run_test test_build_rosetta_testnet_generic_deb

    # Daemon packages
    run_test test_build_daemon_mainnet_deb
    run_test test_build_daemon_mainnet_config_deb
    run_test test_build_daemon_devnet_deb
    run_test test_build_daemon_devnet_config_deb

    # Pre-hardfork packages
    run_test test_build_daemon_mainnet_pre_hardfork_deb
    run_test test_build_daemon_devnet_pre_hardfork_deb

    # Testnet generic
    run_test test_build_daemon_testnet_generic_deb

    # Archive packages
    run_test test_build_archive_devnet_deb
    run_test test_build_archive_testnet_generic_deb
    run_test test_build_archive_mainnet_deb

    # Hardfork config packages
    run_test test_build_daemon_devnet_hardfork_config_deb
    run_test test_build_daemon_mainnet_hardfork_config_deb

    # Utility packages
    run_test test_build_zkapp_test_transaction_deb
    run_test test_build_delegation_verify_deb
    run_test test_build_create_legacy_genesis_deb

    # Naming variants
    run_test test_build_daemon_devnet_lightnet_naming
    run_test test_build_daemon_testnet_generic_lightnet_naming
    run_test test_build_archive_testnet_generic_suffix_naming
    run_test test_build_daemon_devnet_instrumented_naming

    # Codename dependency variants
    run_test test_codename_noble_deps
    run_test test_codename_noble_archive_deps

    # Control file structure
    run_test test_control_file_common_fields

    # Known broken functions (expected to fail)
    run_test_expect_fail test_build_daemon_testnet_generic_hardfork_config_deb_fails

    # Cleanup
    teardown_test_environment

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

main "$@"

#!/bin/bash

# Release Manager Test Library
# Shared functions, configuration, and test cases for release manager tests.
# Sourced by test.sh and test-e2e.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BACKEND="local"

# Test configuration - unsigned repository
TEST_BUCKET="test.packages.o1test.net"
TEST_BUCKET_EXTERNAL_URL="s3.us-west-2.amazonaws.com/test.packages.o1test.net"
TEST_REGION="us-west-2"
TEST_CODENAME="bullseye"
TEST_COMPONENT_CI="ci"
TEST_COMPONENT_TEST="test"
TEST_ARCH="amd64"

# Test configuration - signed repository
SIGNED_TEST_BUCKET="signed.tests.packages.o1test.net"
SIGNED_TEST_BUCKET_EXTERNAL_URL="s3.us-west-2.amazonaws.com/signed.tests.packages.o1test.net"
SIGNED_TEST_COMPONENT="ci"
SIGNED_TEST_CODENAME="bookworm"
SIGNED_TEST_ARCH="arm64"
SIGNED_TEST_COMPONENT="test"

DEBIAN_SIGN_KEY="386E9DAC378726A48ED5CE56ADB30D9ACE02F414"

# Generate random suffix for promote operations
RANDOM_SUFFIX="test-$(date +%s)-${RANDOM}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Get script directory (resolves relative to the lib file itself)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_LIB_DIR}/../../../.." && pwd)"
MANAGER_SCRIPT="${REPO_ROOT}/buildkite/scripts/release/manager.sh"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Test assertion helpers
assert_success() {
    local test_name="$1"
    local command_status="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ "$command_status" -eq 0 ]; then
        log_info "✅ TEST PASSED: ${test_name}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "❌ TEST FAILED: ${test_name}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_package_exists() {
    local test_name="$1"
    local package_name="$2"
    local version="$3"
    local codename="$4"
    local component="$5"
    local bucket="$6"
    local region="$7"
    local arch="$8"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    log_info "Checking if package ${package_name} version ${version} exists in ${codename}/${component}"

    # List packages and check if our package exists
    if deb-s3 list \
        --bucket="${bucket}" \
        --s3-region="${region}" \
        --codename="${codename}" \
        --component="${component}" \
        --arch="${arch}" 2>/dev/null | grep -q "^${package_name}[[:space:]]\+${version}"; then
        log_info "✅ TEST PASSED: ${test_name}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "❌ TEST FAILED: ${test_name} - Package not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Pre-setup: install awscli and deb-s3 if missing
# We are running this test on bare agents, so we need to install dependencies
presetup_tools() {
    if ! command -v aws &> /dev/null; then
        log_info "Installing awscli..."
        pip install --user awscli || {
            log_error "Failed to install awscli. Please install manually."
            exit 1
        }
        export PATH="$HOME/.local/bin:$PATH"
    fi

    if ! command -v deb-s3 &> /dev/null; then
        log_info "Installing deb-s3..."

        # Ensure Ruby and RubyGems are installed
        if ! command -v gem &> /dev/null; then
            log_info "RubyGems not found. Installing Ruby and RubyGems..."
            if command -v apt-get &> /dev/null; then
                apt-get update && apt-get install -y ruby ruby-dev build-essential
            else
                log_error "Could not install Ruby"
                exit 1
            fi
        fi

        local DEBS3_VERSION="0.11.7"
        curl -sLO https://github.com/MinaProtocol/deb-s3/releases/download/${DEBS3_VERSION}/deb-s3-${DEBS3_VERSION}.gem
        gem install deb-s3-${DEBS3_VERSION}.gem
        rm -f deb-s3-${DEBS3_VERSION}.gem
    fi
}

# Prerequisites check
# Pass additional optional dependency descriptions as arguments
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_deps=()
    local optional_deps=()

    # Check for deb-s3
    if ! command -v deb-s3 &> /dev/null; then
        missing_deps+=("deb-s3 (install with: gem install deb-s3)")
    fi

    # Check for aws CLI
    if ! command -v aws &> /dev/null; then
        missing_deps+=("aws (AWS CLI)")
    fi

    # Check for manager script
    if [ ! -f "${MANAGER_SCRIPT}" ]; then
        log_error "Manager script not found at: ${MANAGER_SCRIPT}"
        return 1
    fi

    # Check AWS credentials
    if [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
        log_warn "AWS credentials not set. Some tests may fail."
        log_warn "Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables."
    fi

    # Optional: Check for GPG (needed for signed repo tests)
    if ! command -v gpg &> /dev/null; then
        optional_deps+=("gpg (for signed repository tests)")
    fi

    # Caller-provided optional deps
    for dep in "$@"; do
        optional_deps+=("${dep}")
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            log_error "  - ${dep}"
        done
        return 1
    fi

    if [ ${#optional_deps[@]} -gt 0 ]; then
        log_warn "Optional dependencies not found (some tests will be skipped):"
        for dep in "${optional_deps[@]}"; do
            log_warn "  - ${dep}"
        done
    fi

    log_info "Core prerequisites met"
    return 0
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment..."

    # Create temporary directory for test artifacts
    TEST_TEMP_DIR=$(mktemp -d -t release-manager-test.XXXXXX)
    export TEST_TEMP_DIR
    log_info "Created temporary directory: ${TEST_TEMP_DIR}"

    # Set debian cache to temp dir to avoid polluting user's cache
    export DEBIAN_CACHE_FOLDER="${TEST_TEMP_DIR}/debian_cache"
    mkdir -p "${DEBIAN_CACHE_FOLDER}"

    log_info "Test environment ready"
}

# Cleanup test environment
cleanup_test_environment() {
    log_info "Cleaning up test environment..."

    if [ -n "${TEST_TEMP_DIR}" ] && [ -d "${TEST_TEMP_DIR}" ]; then
        rm -rf "${TEST_TEMP_DIR}"
        log_info "Removed temporary directory: ${TEST_TEMP_DIR}"
    fi
}

# Print test summary
print_test_summary() {
    log_info "========================================="
    log_info "TEST SUMMARY"
    log_info "========================================="
    log_info "Total tests:  ${TESTS_TOTAL}"
    log_info "Passed:       ${TESTS_PASSED}"
    log_info "Failed:       ${TESTS_FAILED}"
    log_info "========================================="

    if [ "${TESTS_FAILED}" -eq 0 ]; then
        log_info "🎉 All tests passed!"
        return 0
    else
        log_error "💔 Some tests failed"
        return 1
    fi
}

# Common bootstrap: presetup, configure aws, check prereqs, setup env, register cleanup trap
# Pass additional optional dependency descriptions as arguments
bootstrap_test_environment() {
    presetup_tools
    aws configure set default.region "${TEST_REGION}"

    if ! check_prerequisites "$@"; then
        log_error "Prerequisites check failed. Exiting."
        exit 1
    fi

    setup_test_environment
    trap cleanup_test_environment EXIT
}

###############################################################################
# Dry-run test functions (shared by both quick and e2e suites)
###############################################################################

# Test: Verify test packages exist in CI component
test_verify_test_packages() {
    log_info "========================================="
    log_info "TEST: Verify test packages exist in CI component"
    log_info "========================================="

    # These are the packages the user uploaded
    assert_package_exists \
        "mina-devnet test package exists" \
        "mina-devnet" \
        "3.3.0-alpha1-compatible-918b8c0" \
        "${TEST_CODENAME}" \
        "${TEST_COMPONENT_CI}" \
        "${TEST_BUCKET}" \
        "${TEST_REGION}" \
        "${TEST_ARCH}"


    assert_package_exists \
        "mina-logproc test package exists" \
        "mina-logproc" \
        "3.3.0-beta1-dkijania-berkeley-automode-05a597d" \
        "${TEST_CODENAME}" \
        "${TEST_COMPONENT_CI}" \
        "${TEST_BUCKET}" \
        "${TEST_REGION}" \
        "${TEST_ARCH}"
}

# Test: Test manager.sh verify command
test_manager_verify() {
    log_info "========================================="
    log_info "TEST: Test manager.sh verify command"
    log_info "========================================="

    # Test verify command with
    if "${MANAGER_SCRIPT}" verify \
        --version "3.3.0-alpha1-compatible-918b8c0" \
        --artifacts "mina-daemon" \
        --networks "devnet" \
        --codenames "${TEST_CODENAME}" \
        --channel "${TEST_COMPONENT_CI}" \
        --archs "${TEST_ARCH}" \
        --debian-repo "${TEST_BUCKET_EXTERNAL_URL}" \
        --only-debians  2>&1 | tee "${TEST_TEMP_DIR}/verify_dry_run.log"; then
        assert_success "Manager verify command " 0
    else
        assert_success "Manager verify command" 1
    fi
}

# Test: Test promote operation (dry-run) - unsigned repo
test_manager_promote_unsigned() {
    log_info "========================================="
    log_info "TEST: Test manager.sh promote command (unsigned, dry-run)"
    log_info "========================================="

    local target_version="3.3.0-alpha1-${RANDOM_SUFFIX}"
    log_info "Using random target version: ${target_version}"

    # Test promote from ci to test component
    if "${MANAGER_SCRIPT}" promote \
        --source-version "3.3.0-alpha1-compatible-918b8c0" \
        --target-version "${target_version}" \
        --source-channel "${TEST_COMPONENT_CI}" \
        --target-channel "${TEST_COMPONENT_TEST}" \
        --artifacts "mina-daemon" \
        --networks "devnet" \
        --codenames "${TEST_CODENAME}" \
        --arch "${TEST_ARCH}" \
        --debian-repo "${TEST_BUCKET}" \
        --only-debians \
        --skip-cache-invalidation \
        --dry-run 2>&1 | tee "${TEST_TEMP_DIR}/promote_unsigned_dry_run.log"; then
        assert_success "Manager promote command (unsigned, dry-run)" 0
    else
        assert_success "Manager promote command (unsigned, dry-run)" 1
    fi
}

# Test: Test promote operation (dry-run) - signed repo
test_manager_promote_signed() {
    log_info "========================================="
    log_info "TEST: Test manager.sh promote command (signed, dry-run)"
    log_info "========================================="

    local target_version="3.3.0-${RANDOM_SUFFIX}"
    log_info "Using random target version: ${target_version}"
    log_info "Using signing key: ${DEBIAN_SIGN_KEY}"

    # Test promote from ci to test component with signing
    if "${MANAGER_SCRIPT}" promote \
        --source-version "3.3.0-8c0c2e6" \
        --target-version "${target_version}" \
        --source-channel "${TEST_COMPONENT_CI}" \
        --target-channel "${SIGNED_TEST_COMPONENT}" \
        --artifacts "mina-archive" \
        --networks "devnet" \
        --codenames "${SIGNED_TEST_CODENAME}" \
        --arch "${SIGNED_TEST_ARCH}" \
        --debian-repo "${SIGNED_TEST_BUCKET}" \
        --debian-sign-key "${DEBIAN_SIGN_KEY}" \
        --skip-cache-invalidation \
        --only-debians \
        --dry-run 2>&1 | tee "${TEST_TEMP_DIR}/promote_signed_dry_run.log"; then
        assert_success "Manager promote command (signed, dry-run)" 0
    else
        assert_success "Manager promote command (signed, dry-run)" 1
    fi
}

# Test: Test publish operation (dry-run) - signed repo
test_manager_publish_signed() {
    log_info "========================================="
    log_info "TEST: Test manager.sh publish command (signed, dry-run)"
    log_info "========================================="

    log_info "Using signing key: ${DEBIAN_SIGN_KEY}"

    # Test publish with signing
    # Note: This test uses --dry-run so it won't actually need the build artifacts
    if "${MANAGER_SCRIPT}" publish \
        --buildkite-build-id "test_data" \
        --source-version "3.3.0-8c0c2e6" \
        --target-version "3.3.0-8c0c2e6-${RANDOM_SUFFIX}" \
        --channel "${SIGNED_TEST_COMPONENT}" \
        --artifacts "mina-archive" \
        --networks "devnet" \
        --codenames "${SIGNED_TEST_CODENAME}" \
        --archs "${SIGNED_TEST_ARCH}" \
        --debian-repo "${SIGNED_TEST_BUCKET}" \
        --debian-sign-key "${DEBIAN_SIGN_KEY}" \
        --backend "${BACKEND}" \
        --only-debians \
        --strip-network-from-archive \
        --skip-cache-invalidation \
        --dry-run 2>&1 | tee "${TEST_TEMP_DIR}/publish_signed_dry_run.log"; then
        assert_success "Manager publish command (signed, dry-run)" 0
    else
        assert_success "Manager publish command (signed, dry-run)" 1
    fi
}

# Test: Test list packages functionality
test_list_packages() {
    log_info "========================================="
    log_info "TEST: Test list packages in repository"
    log_info "========================================="

    log_info "Listing all packages in ${TEST_COMPONENT_CI} component..."
    if deb-s3 list \
        --bucket="${TEST_BUCKET}" \
        --s3-region="${TEST_REGION}" \
        --codename="${TEST_CODENAME}" \
        --component="${TEST_COMPONENT_CI}" \
        --arch="${TEST_ARCH}" > "${TEST_TEMP_DIR}/packages_list.txt" 2>&1; then

        log_info "Packages found:"
        cat "${TEST_TEMP_DIR}/packages_list.txt"
        assert_success "List packages in test repository" 0
    else
        log_error "Failed to list packages"
        assert_success "List packages in test repository" 1
    fi
}

# Convenience: run all dry-run tests
run_dry_run_tests() {
    test_list_packages
    test_verify_test_packages
    test_manager_verify
    test_manager_promote_unsigned
    test_manager_promote_signed
    test_manager_publish_signed
}

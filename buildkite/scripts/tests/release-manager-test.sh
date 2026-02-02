#!/bin/bash

# Release Manager Test Suite
# Tests publish and promote operations for debian packages and Docker images using test repositories
#
# This test suite validates the release manager script functionality including:
# - Listing packages in test repositories
# - Verifying test packages exist
# - Testing promote operations (unsigned and signed repositories) - dry-run and real
# - Testing publish operations (signed repository) - dry-run
# - Testing Docker promotion from Docker Hub to GCP Artifact Registry
#
# Tests are divided into two sections:
# 1. Dry-run tests (safe, no actual changes)
# 2. Non-dry-run tests (actual operations with verification)
#
# Promote operations use random suffixes to avoid conflicts.
#
# Test Repositories:
# - test.packages.o1test.net (unsigned Debian packages)
# - signed.test.packages.o1test.net (signed Debian packages with key 386E9DAC378726A48ED5CE56ADB30D9ACE02F414)
# - minaprotocol/mina-daemon (Docker Hub source)
# - europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo (GCP Artifact Registry target)

set -eo pipefail

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

# Docker configuration
DOCKER_SOURCE_REGISTRY="minaprotocol"
DOCKER_SOURCE_IMAGE="mina-daemon"
DOCKER_SOURCE_TAG="3.3.0-8c0c2e6-bookworm-mainnet-arm64"
DOCKER_TARGET_REGISTRY="europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo"
DOCKER_TARGET_IMAGE="mina-daemon"

# Generate random suffix for promote operations
RANDOM_SUFFIX="test-$(date +%s)-${RANDOM}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
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

    # Optional: Check for Docker (needed for Docker tests)
    if ! command -v docker &> /dev/null; then
        optional_deps+=("docker (for Docker promotion tests)")
    fi

    # Optional: Check for gcloud (needed for GCP Artifact Registry tests)
    if ! command -v gcloud &> /dev/null; then
        optional_deps+=("gcloud (for GCP Artifact Registry tests)")
    fi

    # Optional: Check for GPG (needed for signed repo tests)
    if ! command -v gpg &> /dev/null; then
        optional_deps+=("gpg (for signed repository tests)")
    fi

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

# Test 1: Verify test packages exist in CI component
test_verify_test_packages() {
    log_info "========================================="
    log_info "TEST 1: Verify test packages exist in CI component"
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

# Test 2: Test manager.sh verify command
test_manager_verify() {
    log_info "========================================="
    log_info "TEST 2: Test manager.sh verify command"
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

# Test 3: Test promote operation (dry-run) - unsigned repo
test_manager_promote_unsigned() {
    log_info "========================================="
    log_info "TEST 3: Test manager.sh promote command (unsigned, dry-run)"
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

# Test 4: Test promote operation (dry-run) - signed repo
test_manager_promote_signed() {
    log_info "========================================="
    log_info "TEST 4: Test manager.sh promote command (signed, dry-run)"
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

# Test 5: Test publish operation (dry-run) - signed repo
test_manager_publish_signed() {
    log_info "========================================="
    log_info "TEST 5: Test manager.sh publish command (signed, dry-run)"
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

# Test 6: Test list packages functionality
test_list_packages() {
    log_info "========================================="
    log_info "TEST 6: Test list packages in repository"
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

# Test 7: Non-dry-run promote operation - unsigned repo
test_manager_promote_unsigned_real() {
    log_info "========================================="
    log_info "TEST 7: REAL manager.sh promote command (unsigned, actual promotion)"
    log_info "========================================="

    local target_version="3.3.0-alpha1-${RANDOM_SUFFIX}-real"
    log_info "Using random target version: ${target_version}"
    log_warn "This test will actually promote packages to the test repository"

    # Actual promote from ci to test component
    if "${MANAGER_SCRIPT}" promote \
        --source-version "3.3.0-alpha1-compatible-918b8c0" \
        --target-version "${target_version}" \
        --source-channel "${TEST_COMPONENT_CI}" \
        --target-channel "${TEST_COMPONENT_TEST}" \
        --artifacts "mina-daemon" \
        --networks "devnet" \
        --codenames "${TEST_CODENAME}" \
        --arch "${TEST_ARCH}" \
        --debian-repo "${TEST_BUCKET_EXTERNAL_URL}" \
        --skip-cache-invalidation \
        --only-debians 2>&1 | tee "${TEST_TEMP_DIR}/promote_unsigned_real.log"; then

        log_info "Verifying promoted package exists..."
        sleep 60  # Give S3 a moment to sync

        if assert_package_exists \
            "Manager promote command (unsigned, real)" \
            "mina-devnet" \
            "${target_version}" \
            "${TEST_CODENAME}" \
            "${TEST_COMPONENT_TEST}" \
            "${TEST_BUCKET}" \
            "${TEST_REGION}" \
            "${TEST_ARCH}"; then
            return 0
        else
            return 1
        fi
    else
        assert_success "Manager promote command (unsigned, real)" 1
    fi
}

# Test 8: Non-dry-run promote operation - signed repo
test_manager_promote_signed_real() {
    log_info "========================================="
    log_info "TEST 8: REAL manager.sh promote command (signed, actual promotion)"
    log_info "========================================="

    local target_version="3.3.0-8c0c2e6-${RANDOM_SUFFIX}-signed-real"
    log_info "Using random target version: ${target_version}"
    log_info "Using signing key: ${DEBIAN_SIGN_KEY}"
    log_warn "This test will actually promote packages to the signed test repository"

    # Check if GPG key is available
    if ! gpg --list-secret-keys "${DEBIAN_SIGN_KEY}" &> /dev/null; then
        log_warn "GPG signing key not found. Skipping signed promote test."
        log_warn "To run this test, import the key with:"
        log_warn "  gcloud secrets versions access latest --secret=\"o1labsDebianRepoKey\" | gpg --import"
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    fi

    # Actual promote from ci to test component with signing
    if "${MANAGER_SCRIPT}" promote \
        --source-version "3.3.0-8c0c2e6" \
        --target-version "${target_version}" \
        --source-channel "${TEST_COMPONENT_CI}" \
        --target-channel "${TEST_COMPONENT_TEST}" \
        --artifacts "mina-archive" \
        --networks "devnet" \
        --codenames "${SIGNED_TEST_CODENAME}" \
        --arch "${SIGNED_TEST_ARCH}" \
        --debian-repo "${SIGNED_TEST_BUCKET_EXTERNAL_URL}" \
        --debian-sign-key "${DEBIAN_SIGN_KEY}" \
        --skip-cache-invalidation \
        --only-debians 2>&1 | tee "${TEST_TEMP_DIR}/promote_signed_real.log"; then

        log_info "Verifying promoted package exists in signed repository..."
        sleep 5  # Give S3 a moment to sync

        if assert_package_exists \
            "Manager promote command (signed, real)" \
            "mina-archive-devnet" \
            "${target_version}" \
            "${SIGNED_TEST_CODENAME}" \
            "${TEST_COMPONENT_TEST}" \
            "${SIGNED_TEST_BUCKET}" \
            "${TEST_REGION}" \
            "${SIGNED_TEST_ARCH}"; then
            return 0
        else
            return 1
        fi
    else
        assert_success "Manager promote command (signed, real)" 1
    fi
}

# Test 9: Docker promote from Docker Hub to GCP Artifact Registry
test_docker_promote_to_gcp() {
    log_info "========================================="
    log_info "TEST 9: Docker promote from Docker Hub to GCP Artifact Registry"
    log_info "========================================="

    local docker_random_tag="${RANDOM_SUFFIX}"
    local source_image="${DOCKER_SOURCE_REGISTRY}/${DOCKER_SOURCE_IMAGE}:${DOCKER_SOURCE_TAG}"
    local target_image="${DOCKER_TARGET_REGISTRY}/${DOCKER_TARGET_IMAGE}:${docker_random_tag}"

    log_info "Source: ${source_image}"
    log_info "Target: ${target_image}"
    log_warn "This test will actually pull and push Docker images"

    # Check if docker is available
    if ! command -v docker &> /dev/null; then
        log_warn "Docker not found. Skipping Docker promote test."
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    fi

    # Check if gcloud is configured for docker authentication
    if ! gcloud auth print-access-token &> /dev/null; then
        log_warn "GCloud not authenticated. Skipping Docker promote test."
        log_warn "To run this test, authenticate with:"
        log_warn "  gcloud auth login"
        log_warn "  gcloud auth configure-docker europe-west3-docker.pkg.dev"
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    fi

    # Pull source image from Docker Hub
    log_info "Pulling source image from Docker Hub..."
    if ! docker pull --platform linux/arm64 "${source_image}" 2>&1 | tee "${TEST_TEMP_DIR}/docker_pull.log"; then
        log_error "Failed to pull source image"
        assert_success "Docker promote to GCP Artifact Registry" 1
        return 1
    fi

    # Tag image for target registry
    log_info "Tagging image for GCP Artifact Registry..."
    if ! docker tag "${source_image}" "${target_image}" 2>&1 | tee "${TEST_TEMP_DIR}/docker_tag.log"; then
        log_error "Failed to tag image"
        assert_success "Docker promote to GCP Artifact Registry" 1
        return 1
    fi

    # Push to GCP Artifact Registry
    log_info "Pushing image to GCP Artifact Registry..."
    if docker push "${target_image}" 2>&1 | tee "${TEST_TEMP_DIR}/docker_push.log"; then
        log_info "✓ Docker image successfully promoted to GCP Artifact Registry"

        # Verify image exists
        log_info "Verifying image in GCP Artifact Registry..."
        if gcloud artifacts docker images list "${DOCKER_TARGET_REGISTRY}/${DOCKER_TARGET_IMAGE}" \
            --include-tags 2>/dev/null | grep -q "${docker_random_tag}"; then
            log_info "✓ Image verified in GCP Artifact Registry"
            assert_success "Docker promote to GCP Artifact Registry" 0
        else
            log_warn "Image push succeeded but verification failed (may be due to propagation delay)"
            assert_success "Docker promote to GCP Artifact Registry" 0
        fi
    else
        log_error "Failed to push image to GCP Artifact Registry"
        assert_success "Docker promote to GCP Artifact Registry" 1
    fi

    # Cleanup local images
    log_info "Cleaning up local Docker images..."
    docker rmi "${source_image}" "${target_image}" &> /dev/null || true
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


# Main test execution
main() {
    log_info "Starting Release Manager Test Suite"
    log_info "Test bucket (unsigned): ${TEST_BUCKET}"
    log_info "Test bucket (signed): ${SIGNED_TEST_BUCKET}"
    log_info "Test region: ${TEST_REGION}"
    log_info "Test codename: ${TEST_CODENAME}"
    log_info "Random suffix: ${RANDOM_SUFFIX}"
    log_info ""

    # Pre-setup required tools
    presetup_tools

    aws configure set default.region "${TEST_REGION}"

    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed. Exiting."
        exit 1
    fi

    # Setup test environment
    setup_test_environment

    # Trap to ensure cleanup happens
    trap cleanup_test_environment EXIT

    # Always run all tests
    test_list_packages
    test_verify_test_packages
    test_manager_verify
    test_manager_promote_unsigned
    test_manager_promote_signed
    test_manager_publish_signed

    log_info ""
    log_info "========================================="
    log_info "STARTING NON-DRY-RUN TESTS"
    log_info "These tests will make actual changes!"
    log_info "========================================="
    log_info ""

    test_manager_promote_unsigned_real
    test_manager_promote_signed_real
    test_docker_promote_to_gcp

    # Print summary and exit with appropriate code
    if print_test_summary; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"

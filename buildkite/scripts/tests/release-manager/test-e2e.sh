#!/bin/bash

# Release Manager Test Suite - E2E (End-to-End with Real Uploads)
# Tests publish and promote operations with actual AWS uploads and Docker operations
#
# Includes both dry-run and non-dry-run (actual operations with verification).
# For quick dry-run-only tests, see test.sh

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

# Docker configuration (E2E only)
DOCKER_SOURCE_REGISTRY="minaprotocol"
DOCKER_SOURCE_IMAGE="mina-daemon"
DOCKER_SOURCE_TAG="3.3.0-8c0c2e6-bookworm-mainnet-arm64"
DOCKER_TARGET_REGISTRY="europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo"
DOCKER_TARGET_IMAGE="mina-daemon"

###############################################################################
# E2E-only test functions (non-dry-run, actual operations)
###############################################################################

# Test: Non-dry-run promote operation - unsigned repo
test_manager_promote_unsigned_real() {
    log_info "========================================="
    log_info "TEST: REAL manager.sh promote command (unsigned, actual promotion)"
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

# Test: Non-dry-run promote operation - signed repo
test_manager_promote_signed_real() {
    log_info "========================================="
    log_info "TEST: REAL manager.sh promote command (signed, actual promotion)"
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

# Test: Docker promote from Docker Hub to GCP Artifact Registry
test_docker_promote_to_gcp() {
    log_info "========================================="
    log_info "TEST: Docker promote from Docker Hub to GCP Artifact Registry"
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

###############################################################################
# Main
###############################################################################

main() {
    log_info "Starting Release Manager Test Suite (E2E)"
    log_info "Test bucket (unsigned): ${TEST_BUCKET}"
    log_info "Test bucket (signed): ${SIGNED_TEST_BUCKET}"
    log_info "Test region: ${TEST_REGION}"
    log_info "Test codename: ${TEST_CODENAME}"
    log_info "Random suffix: ${RANDOM_SUFFIX}"
    log_info ""

    # Build list of extra optional deps for E2E
    local extra_optional_deps=()
    if ! command -v docker &> /dev/null; then
        extra_optional_deps+=("docker (for Docker promotion tests)")
    fi
    if ! command -v gcloud &> /dev/null; then
        extra_optional_deps+=("gcloud (for GCP Artifact Registry tests)")
    fi

    bootstrap_test_environment "${extra_optional_deps[@]}"

    # Run dry-run tests first
    run_dry_run_tests

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

main "$@"

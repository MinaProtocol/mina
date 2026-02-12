#!/bin/bash

# Release Manager Test Suite - Quick (Dry-Run Only)
# Tests publish and promote operations using dry-run mode (no actual AWS uploads)
#
# All tests are safe and do not make actual changes to repositories.
# For E2E tests with real uploads, see test-e2e.sh

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

main() {
    log_info "Starting Release Manager Test Suite (Quick / Dry-Run)"
    log_info "Test bucket (unsigned): ${TEST_BUCKET}"
    log_info "Test bucket (signed): ${SIGNED_TEST_BUCKET}"
    log_info "Test region: ${TEST_REGION}"
    log_info "Test codename: ${TEST_CODENAME}"
    log_info "Random suffix: ${RANDOM_SUFFIX}"
    log_info ""

    bootstrap_test_environment

    # Run dry-run tests only (quick, no AWS uploads)
    run_dry_run_tests

    # Print summary and exit with appropriate code
    if print_test_summary; then
        exit 0
    else
        exit 1
    fi
}

main "$@"

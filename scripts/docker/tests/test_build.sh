#!/bin/bash
set -euo pipefail

################################################################################
# Test suite for scripts/docker/build.sh
#
# Usage:
#   bash scripts/docker/tests/test_build.sh
#
# The tests are black box: they run build.sh as a program, with a stub "docker"
# program on the PATH. The stub writes each argument of "docker buildx build" on
# one line of a file, so a test can examine the complete docker command without
# a build. No test calls a function of helper.sh.
#
# The suite is black box on purpose. It is a specification of what build.sh must
# do, and it stays valid if the script is later refactored, or moved to another
# language. A test that calls an internal function does not stay valid.
#
# Two groups of tests are below:
# - "Behaviour": what build.sh must always do.
# - "Known defects": what build.sh does today, which is not correct. Each of
#   these tests has a DEFECT note. When you repair a defect, the related test
#   fails. That is the intention: change the test in the same change-set.
################################################################################

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

################################################################################
# Test framework
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

assert_file_absent() {
    local label="$1" path="$2"
    if [[ -e "$path" ]]; then
        log_fail "${label}: '${path}' exists"
    else
        log_pass
    fi
}

assert_file_exists() {
    local label="$1" path="$2"
    if [[ -e "$path" ]]; then
        log_pass
    else
        log_fail "${label}: '${path}' does not exist"
    fi
}

# The stub writes one argument on each line, so an exact line match is precise.
assert_has_line() {
    local label="$1" file="$2" line="$3"
    if grep -qFx -- "$line" "$file"; then
        log_pass
    else
        log_fail "${label}: the docker command has no argument '${line}'"
    fi
}

assert_no_line() {
    local label="$1" file="$2" line="$3"
    if grep -qFx -- "$line" "$file"; then
        log_fail "${label}: the docker command must not have the argument '${line}'"
    else
        log_pass
    fi
}

assert_matches() {
    local label="$1" file="$2" pattern="$3"
    if grep -qE -- "$pattern" "$file"; then
        log_pass
    else
        log_fail "${label}: no argument matches '${pattern}'"
    fi
}

run_test() {
    CURRENT_TEST="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    local failures_before=${TESTS_FAILED}

    echo -n "TEST: ${CURRENT_TEST} ... "

    # "|| true" stops an error in one test from stopping the suite.
    "$1" || true

    if [[ ${TESTS_FAILED} -eq ${failures_before} ]]; then
        echo "OK"
    else
        echo "FAILED"
    fi
}

################################################################################
# Stub docker
################################################################################

STUB_DIR=""
LAST_EXIT=0

setup_stub_docker() {
    STUB_DIR="$(mktemp -d)"
    cat > "${STUB_DIR}/docker" <<'STUB'
#!/usr/bin/env bash
# Record the arguments of the build only. The other calls (the setup of buildx,
# the inspection of the network) must not change the recorded command.
if [[ "${1:-}" == "buildx" && "${2:-}" == "build" ]]; then
    printf '%s\n' "$@" > "${DOCKER_ARGS_FILE}"
    exit 0
fi
# "docker network inspect" gives the gateway of the bridge network.
if [[ "${1:-}" == "network" ]]; then
    echo "172.17.0.1"
    exit 0
fi
exit 0
STUB
    chmod +x "${STUB_DIR}/docker"
}

teardown_stub_docker() {
    [[ -n "$STUB_DIR" && -d "$STUB_DIR" ]] && rm -rf "$STUB_DIR"
    return 0
}

# Run build.sh with fixed git values, so that the tags are the same on every
# machine. OVERRIDE_TAG also stops export-git-env-vars.sh from doing a network
# "git fetch --tags".
#
# The exit code goes into LAST_EXIT. The output goes into "<args file>.log".
run_build() {
    local args_file="$1"
    shift
    rm -f "$args_file"
    set +e
    ( cd "$REPO_ROOT" && \
      PATH="${STUB_DIR}:${PATH}" \
      DOCKER_ARGS_FILE="$args_file" \
      OVERRIDE_GITHASH="abcdefgh" \
      OVERRIDE_TAG="3.0.0" \
      BRANCH_NAME="test-branch" \
      MINA_DEB_CODENAME="bullseye" \
      KEEP_MY_TAGS_INTACT="true" \
      CI="" BUILDKITE="" GITHUB_ACTIONS="" \
      ./scripts/docker/build.sh "$@" ) > "${args_file}.log" 2>&1
    LAST_EXIT=$?
    set -e
    touch "$args_file"
}

################################################################################
# Behaviour
################################################################################

test_daemon_command() {
    local args="${STUB_DIR}/daemon.args"
    run_build "$args" \
        --service mina-daemon \
        --version 3.1.0 \
        --network devnet \
        --docker-registry testreg \
        --deb-codename bullseye \
        --deb-build-flags none

    assert_eq "exit code" 0 "$LAST_EXIT"
    assert_has_line "dockerfile" "$args" "dockerfiles/Dockerfile-mina-daemon"
    assert_has_line "context" "$args" "dockerfiles/"
    assert_has_line "base image" "$args" "image=debian:bullseye-slim"
    assert_has_line "network" "$args" "network=devnet"
    assert_has_line "codename" "$args" "deb_codename=bullseye"
    assert_has_line "release defaults to unstable" "$args" "deb_release=unstable"
    assert_has_line "architecture defaults to all" "$args" "deb_arch=all"
    assert_has_line "branch defaults to compatible" "$args" "MINA_BRANCH=compatible"
    assert_has_line "the debian version defaults to the version" "$args" "deb_version=3.1.0"
    # The build argument "version" keeps the version without the network.
    assert_has_line "version build argument" "$args" "version=3.1.0"
    assert_has_line "readable tag" "$args" "testreg/mina-daemon:3.1.0-devnet"
    assert_has_line "hash tag" "$args" "testreg/mina-daemon:abcdefg-bullseye-devnet"
    assert_has_line "push by default" "$args" "--push"
}

test_load_only_does_not_push() {
    local args="${STUB_DIR}/load.args"
    run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none --load-only

    assert_has_line "load" "$args" "--load"
    assert_no_line "no push" "$args" "--push"
}

test_archive_mainnet_noble() {
    local args="${STUB_DIR}/archive.args"
    run_build "$args" \
        --service mina-archive --version 3.1.0 --network mainnet \
        --docker-registry testreg --deb-codename noble --deb-build-flags none

    assert_has_line "dockerfile" "$args" "dockerfiles/Dockerfile-mina-archive"
    assert_has_line "ubuntu base image" "$args" "image=ubuntu:noble"
    assert_has_line "tag holds the network" "$args" "testreg/mina-archive:3.1.0-mainnet"
    assert_has_line "hash tag holds the codename" "$args" \
        "testreg/mina-archive:abcdefg-noble-mainnet"
}

test_generic_suffix_reaches_tag_and_build_arg() {
    local args="${STUB_DIR}/generic.args"
    run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-suffix generic --deb-build-flags none

    assert_has_line "the build argument has no dash at the start" "$args" "deb_suffix=generic"
    assert_has_line "tag holds the suffix" "$args" "testreg/mina-daemon:3.1.0-devnet-generic"
}

# The order of the parts must be the same as the Debian package naming in
# scripts/debian/builder-helpers.sh: custom suffix, profile, build flags.
test_suffix_order_is_generic_lightnet_instrumented() {
    local args="${STUB_DIR}/instr.args"
    run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg \
        --deb-suffix generic --deb-profile lightnet --deb-build-flags instrumented

    assert_has_line "complete suffix" "$args" "deb_suffix=generic-lightnet-instrumented"
    assert_has_line "build flags suffix" "$args" "build_flags_suffix=-instrumented"
    assert_has_line "tag" "$args" \
        "testreg/mina-daemon:3.1.0-devnet-generic-lightnet-instrumented"
}

# A *-configured service starts FROM the image that --version names, but its own
# tag uses MINA_DOCKER_TAG, because the image holds the configuration of this
# commit. Here MINA_DOCKER_TAG is 3.0.0-test-branch-abcdefg-bullseye.
test_configured_service_uses_docker_tag_for_the_output() {
    local args="${STUB_DIR}/configured.args"
    run_build "$args" \
        --service mina-daemon-configured --version 3.1.0 --network devnet \
        --docker-registry testreg --custom-suffix configured --deb-build-flags none

    assert_has_line "dockerfile" "$args" "dockerfiles/stages/install-config"
    assert_has_line "the version names the base image" "$args" "version=3.1.0"
    assert_has_line "output tag" "$args" \
        "testreg/mina-daemon:3.0.0-test-branch-abcdefg-bullseye-devnet-configured"
    assert_has_line "custom suffix has a dash at the start" "$args" "custom_suffix=-configured"
}

# A value that holds a space must stay one argument.
test_custom_arg_keeps_a_value_with_a_space() {
    local args="${STUB_DIR}/custom.args"
    run_build "$args" \
        --service mina-rosetta-configured --version 3.1.0 --network devnet \
        --docker-registry testreg --custom-suffix configured --deb-build-flags none \
        --custom-arg "--build-arg image_name=mina-rosetta"

    assert_has_line "the option of the custom argument" "$args" "--build-arg"
    assert_has_line "the value of the custom argument" "$args" "image_name=mina-rosetta"
    assert_has_line "the rosetta image keeps its own name" "$args" \
        "testreg/mina-rosetta:3.0.0-test-branch-abcdefg-bullseye-devnet-configured"
}

test_arm64_gets_a_platform_suffix() {
    local args="${STUB_DIR}/arm.args"
    run_build "$args" \
        --service mina-archive --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none --platform linux/arm64

    assert_has_line "platform" "$args" "linux/arm64"
    assert_has_line "the tag has the platform suffix" "$args" \
        "testreg/mina-archive:3.1.0-devnet-arm64"
}

test_toolchain_joins_the_stage_files() {
    local args="${STUB_DIR}/toolchain.args"
    run_build "$args" \
        --service mina-toolchain --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    # The Dockerfile is a temporary file, so only the start of the path is fixed.
    assert_matches "a temporary Dockerfile holds the joined stages" "$args" \
        "^/tmp/Dockerfile-toolchain\."
    assert_has_line "the toolchain tag has no network" "$args" "testreg/mina-toolchain:3.1.0"
}

# Every service has a build context now: each image installs its packages from
# files in that context.
test_delegation_verifier_has_a_build_context() {
    local args="${STUB_DIR}/deleg.args"
    run_build "$args" \
        --service mina-delegation-verifier --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    assert_has_line "context" "$args" "dockerfiles/"
    assert_has_line "dockerfile" "$args" \
        "dockerfiles/Dockerfile-delegation-stateless-verifier"
    assert_no_line "the Dockerfile does not come on stdin" "$args" "-"
    assert_has_line "tag" "$args" "testreg/mina-delegation-verifier:3.1.0"
}

# The images install their packages from files in the build context, so no
# Debian repository reaches the build, and --deb-repo is not an option any more.
test_no_debian_repository_reaches_the_build() {
    local args="${STUB_DIR}/repo.args"
    run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    if grep -q "^deb_repo=" "$args"; then
        log_fail "the build still gets a deb_repo build argument"
    else
        log_pass
    fi

    # An old caller that still gives --deb-repo must stop, not build with a
    # repository that the image ignores.
    run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-repo http://localhost:8080
    if [[ "$LAST_EXIT" -eq 0 ]]; then
        log_fail "--deb-repo must not be accepted"
    else
        log_pass
    fi
}

test_cache_options() {
    local args="${STUB_DIR}/cache.args"
    run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none \
        --no-cache --cache-from testreg/cache:x

    assert_has_line "no cache" "$args" "--no-cache"
    assert_has_line "cache source" "$args" "testreg/cache:x"
}

test_optional_build_args_are_absent_when_not_given() {
    local args="${STUB_DIR}/optional.args"
    run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    assert_no_line "no legacy version" "$args" "deb_legacy_version="
    assert_no_line "no storage repair version" "$args" "deb_storage_repair_version="
    assert_no_line "no custom suffix" "$args" "custom_suffix="
    assert_no_line "no image name" "$args" "image_name="
}

test_auto_hardfork_needs_a_legacy_version() {
    local args="${STUB_DIR}/hf.args"
    run_build "$args" \
        --service mina-daemon-auto-hardfork --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    if [[ "$LAST_EXIT" -eq 0 ]]; then
        log_fail "the build must stop when --deb-legacy-version is missing"
    else
        log_pass
    fi
}

test_unknown_service_stops_the_build() {
    local args="${STUB_DIR}/bad.args"
    run_build "$args" --service not-a-service --version 3.1.0 --network devnet

    if [[ "$LAST_EXIT" -eq 0 ]]; then
        log_fail "an unknown service must stop the build"
    else
        log_pass
    fi
}

test_unknown_codename_stops_the_build() {
    local args="${STUB_DIR}/badcode.args"
    run_build "$args" --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-codename sid

    if [[ "$LAST_EXIT" -eq 0 ]]; then
        log_fail "an unknown codename must stop the build"
    else
        log_pass
    fi
}

test_missing_service_or_version_stops_the_build() {
    local args="${STUB_DIR}/missing.args"

    run_build "$args" --version 3.1.0 --network devnet
    if [[ "$LAST_EXIT" -eq 0 ]]; then log_fail "no --service must stop the build"; else log_pass; fi

    run_build "$args" --service mina-daemon --network devnet
    if [[ "$LAST_EXIT" -eq 0 ]]; then log_fail "no --version must stop the build"; else log_pass; fi
}

################################################################################
# Known defects
#
# These tests hold the behaviour of build.sh as it is today. Each one names a
# defect. When the defect is repaired, the test fails, and you must change it in
# the same change-set.
################################################################################

# DEFECT: build.sh has code that gives --network the default "devnet", but that
# code cannot run. scripts/export-git-env-vars.sh does "set -euo pipefail" and
# build.sh sources it, so build.sh runs with "set -u". The test of
# $INPUT_NETWORK then stops the script before the default is used.
# Result: "make docker-build-toolchain", which gives no --network, is broken.
test_DEFECT_network_has_no_working_default() {
    local args="${STUB_DIR}/nonet.args"
    run_build "$args" --service mina-daemon --version 3.1.0 --docker-registry testreg

    if [[ "$LAST_EXIT" -eq 0 ]]; then
        log_fail "REPAIRED: --network now has a default. Delete this test."
    else
        log_pass
    fi
    if grep -q "INPUT_NETWORK: unbound variable" "${args}.log"; then
        log_pass
    else
        log_fail "the reason of the stop changed; read ${args}.log"
    fi
}

# DEFECT: when --deb-build-flags is not given, the build flags suffix is a
# single dash. dockerfiles/stages/install-config puts this value in the name of
# the base image, so the name gets two dashes and the image is not found. The
# value must be empty, as it is for "none".
test_DEFECT_build_flags_suffix_is_a_lone_dash() {
    local args="${STUB_DIR}/flags.args"
    run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet --docker-registry testreg

    if grep -qFx -- "build_flags_suffix=-" "$args"; then
        log_pass
    else
        log_fail "REPAIRED: the suffix is no longer a lone dash. Change this test to expect an empty value."
    fi
}

# DEFECT: the service check uses a substring match:
#   echo "${VALID_SERVICES[@]}" | grep -o "$SERVICE"
# So a partial name passes the check and the build stops later, at the "case"
# statement, with a message that is less clear. Before August 2026 the Makefile
# used the name "mina-daemon-config" and this hid the error.
test_DEFECT_a_partial_service_name_passes_the_check() {
    local args="${STUB_DIR}/partial.args"
    run_build "$args" --service mina-daemon-config --version 3.1.0 --network devnet \
        --docker-registry testreg

    if [[ "$LAST_EXIT" -eq 0 ]]; then
        log_fail "a partial service name must not build"
    else
        log_pass
    fi
    # The message shows which check stopped the build. "Unsupported service"
    # comes from the "case" statement, after the check accepted the name.
    if grep -q "Unsupported service" "${args}.log"; then
        log_pass
    else
        log_fail "REPAIRED: the name check now refuses a partial name. Change this test."
    fi
}

# DEFECT: VALID_SERVICES holds two names that the "case" statement in build.sh
# does not know, so they always stop the build. Delete them.
test_DEFECT_valid_services_holds_names_that_cannot_build() {
    local args="${STUB_DIR}/ghost.args"
    local service
    for service in mina-daemon-generic mina-rosetta-generic; do
        if grep -q "'${service}'" "${REPO_ROOT}/scripts/docker/helper.sh"; then
            log_pass
        else
            log_fail "REPAIRED: ${service} is no longer in VALID_SERVICES. Change this test."
        fi
        run_build "$args" --service "$service" --version 3.1.0 --network devnet \
            --docker-registry testreg
        if [[ "$LAST_EXIT" -eq 0 ]]; then
            log_fail "${service} builds now; VALID_SERVICES and the case statement agree"
        else
            log_pass
        fi
    done
}

# DEFECT: three services point to a Dockerfile that is not in the repository.
# The applications were deleted (commits fa3c67d67c and ca46cf2fc3), but the
# branches in build.sh stayed. Delete them.
test_DEFECT_three_services_point_to_a_dockerfile_that_is_absent() {
    assert_file_absent "leaderboard" "${REPO_ROOT}/frontend/leaderboard/Dockerfile"
    assert_file_absent "delegation-backend" \
        "${REPO_ROOT}/dockerfiles/Dockerfile-delegation-backend"
    assert_file_absent "delegation-backend-toolchain" \
        "${REPO_ROOT}/dockerfiles/Dockerfile-delegation-backend-toolchain"
}

# The services that CI and the Makefile use must point to a Dockerfile that
# exists. This test finds a Dockerfile that a rename or a deletion has lost.
test_live_services_have_a_dockerfile() {
    local f
    for f in \
        dockerfiles/Dockerfile-mina-archive \
        dockerfiles/Dockerfile-mina-daemon \
        dockerfiles/Dockerfile-mina-rosetta \
        dockerfiles/Dockerfile-mina-daemon-hardfork \
        dockerfiles/Dockerfile-txn-burst \
        dockerfiles/Dockerfile-zkapp-test-transaction \
        dockerfiles/Dockerfile-mina-test-suite \
        dockerfiles/Dockerfile-delegation-stateless-verifier \
        dockerfiles/stages/install-config \
        dockerfiles/stages/1-build-deps \
        dockerfiles/stages/2-opam-deps \
        dockerfiles/stages/3-toolchain
    do
        assert_file_exists "$f" "${REPO_ROOT}/${f}"
    done
}

################################################################################
# Main
################################################################################

main() {
    setup_stub_docker

    # Behaviour
    run_test test_daemon_command
    run_test test_load_only_does_not_push
    run_test test_archive_mainnet_noble
    run_test test_generic_suffix_reaches_tag_and_build_arg
    run_test test_suffix_order_is_generic_lightnet_instrumented
    run_test test_configured_service_uses_docker_tag_for_the_output
    run_test test_custom_arg_keeps_a_value_with_a_space
    run_test test_arm64_gets_a_platform_suffix
    run_test test_toolchain_joins_the_stage_files
    run_test test_delegation_verifier_has_a_build_context
    run_test test_no_debian_repository_reaches_the_build
    run_test test_cache_options
    run_test test_optional_build_args_are_absent_when_not_given
    run_test test_auto_hardfork_needs_a_legacy_version
    run_test test_unknown_service_stops_the_build
    run_test test_unknown_codename_stops_the_build
    run_test test_missing_service_or_version_stops_the_build
    run_test test_live_services_have_a_dockerfile

    # Known defects
    run_test test_DEFECT_network_has_no_working_default
    run_test test_DEFECT_build_flags_suffix_is_a_lone_dash
    run_test test_DEFECT_a_partial_service_name_passes_the_check
    run_test test_DEFECT_valid_services_holds_names_that_cannot_build
    run_test test_DEFECT_three_services_point_to_a_dockerfile_that_is_absent

    teardown_stub_docker

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

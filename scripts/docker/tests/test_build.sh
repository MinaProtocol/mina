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

# The value that follows an option, for example the target of --target.
assert_option_value() {
    local label="$1" file="$2" option="$3" expected="$4"
    local actual
    actual="$(grep -A1 -Fx -- "$option" "$file" 2>/dev/null | tail -1)"
    assert_eq "$label" "$expected" "$actual"
}

assert_called() {
    local label="$1" file="$2" pattern="$3"
    if grep -qE -- "$pattern" "$file"; then
        log_pass
    else
        log_fail "${label}: docker was never called with '${pattern}'"
    fi
}

assert_not_called() {
    local label="$1" file="$2" pattern="$3"
    if grep -qE -- "$pattern" "$file"; then
        log_fail "${label}: docker must not be called with '${pattern}'"
    else
        log_pass
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
# Write every call in a log, so a test can see that the image is pushed, and
# write the arguments of the build in their own file, one on each line.
echo "$*" >> "${DOCKER_CALLS_FILE:-/dev/null}"
if [[ "${1:-}" == "buildx" && "${2:-}" == "build" ]]; then
    printf '%s\n' "$@" > "${DOCKER_ARGS_FILE}"
    exit 0
fi
# "docker network inspect" gives the gateway of the bridge network.
if [[ "${1:-}" == "network" ]]; then
    echo "172.17.0.1"
    exit 0
fi
# "docker manifest inspect" asks the registry whether a tag is published.
# build.sh uses it to refuse to overwrite an image that already exists, so the
# stub must answer truthfully: nothing is published in the tests, and the call
# fails, unless a test asks for the tag to be there.
if [[ "${1:-}" == "manifest" ]]; then
    [[ -n "${STUB_TAG_IN_REGISTRY:-}" ]] && exit 0
    exit 1
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
    rm -f "$args_file" "${args_file}.calls"
    set +e
    ( cd "$REPO_ROOT" && \
      PATH="${STUB_DIR}:${PATH}" \
      DOCKER_ARGS_FILE="$args_file" \
      DOCKER_CALLS_FILE="${args_file}.calls" \
      OVERRIDE_GITHASH="abcdefgh" \
      OVERRIDE_TAG="3.0.0" \
      BRANCH_NAME="test-branch" \
      MINA_DEB_CODENAME="bullseye" \
      KEEP_MY_TAGS_INTACT="true" \
      STUB_TAG_IN_REGISTRY="${STUB_TAG_IN_REGISTRY:-}" \
      FORCE_DOCKER_OVERWRITE="${FORCE_DOCKER_OVERWRITE:-}" \
      CI="" BUILDKITE="" GITHUB_ACTIONS="" \
      SKIP_GITBRANCH="" \
      ./scripts/docker/build.sh "$@" ) > "${args_file}.log" 2>&1
    LAST_EXIT=$?
    set -e
    touch "$args_file" "${args_file}.calls"
}

################################################################################
# Behaviour
################################################################################

# Every image is built from the "dockerfiles" context, and every build loads the
# image into the local docker daemon first. A push is a separate docker call.
test_daemon_command() {
    local args="${STUB_DIR}/daemon.args"
    run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-codename bullseye --deb-build-flags none

    assert_eq "exit code" 0 "$LAST_EXIT"
    assert_option_value "target" "$args" "--target" "mina-daemon"
    assert_has_line "context" "$args" "dockerfiles/"
    assert_matches "the stages are joined into a temporary Dockerfile" "$args" \
        "^/tmp/Dockerfile-mina-daemon\."
    assert_has_line "base image" "$args" "image=debian:bullseye-slim"
    assert_has_line "network" "$args" "network=devnet"
    assert_has_line "codename" "$args" "deb_codename=bullseye"
    assert_has_line "release defaults to unstable" "$args" "deb_release=unstable"
    assert_has_line "profile" "$args" "deb_profile=devnet"
    assert_has_line "architecture defaults to all" "$args" "deb_arch=all"
    assert_has_line "branch defaults to compatible" "$args" "MINA_BRANCH=compatible"
    assert_has_line "the debian version defaults to the version" "$args" "deb_version=3.1.0"
    assert_has_line "version build argument" "$args" "version=3.1.0"
    assert_has_line "registry" "$args" "docker_repo=testreg"
    # The daemon tag holds no network. The hash tag always holds one.
    assert_has_line "readable tag" "$args" "testreg/mina-daemon:3.1.0"
    assert_has_line "hash tag" "$args" "testreg/mina-daemon:abcdefg-bullseye-devnet"
    assert_has_line "buildx loads the image" "$args" "--load"
}

# The image is pushed with a separate call, and the hash tag is made in the
# registry, not pushed a second time.
test_push_is_a_separate_docker_call() {
    local args="${STUB_DIR}/push.args"
    run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    assert_called "push" "${args}.calls" "^push testreg/mina-daemon:3\.1\.0$"
    assert_called "the hash tag is made in the registry" "${args}.calls" \
        "^buildx imagetools create"
}

test_load_only_does_not_push() {
    local args="${STUB_DIR}/load.args"
    run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none --load-only

    assert_has_line "buildx still loads" "$args" "--load"
    assert_not_called "no push" "${args}.calls" "^push "
    assert_not_called "no registry tag" "${args}.calls" "^buildx imagetools"
}

# A tag that is already published is not overwritten. The check runs before the
# build, so a build that would be refused costs nothing.
test_published_tag_is_not_overwritten() {
    local args="${STUB_DIR}/exists.args"
    STUB_TAG_IN_REGISTRY="true" run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    assert_eq "exit code" 1 "$LAST_EXIT"
    assert_not_called "nothing is built" "${args}.calls" "^buildx build"
    assert_not_called "nothing is pushed" "${args}.calls" "^push "
}

# FORCE_DOCKER_OVERWRITE is the way past that refusal.
test_force_overwrite_pushes_over_a_published_tag() {
    local args="${STUB_DIR}/force.args"
    STUB_TAG_IN_REGISTRY="true" FORCE_DOCKER_OVERWRITE="1" run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    assert_eq "exit code" 0 "$LAST_EXIT"
    assert_called "push" "${args}.calls" "^push testreg/mina-daemon:3\.1\.0$"
}

# The refusal only guards a push. A load-only build never reaches the registry,
# so it must not ask the registry anything.
test_load_only_ignores_the_published_tag() {
    local args="${STUB_DIR}/load-exists.args"
    STUB_TAG_IN_REGISTRY="true" run_build "$args" \
        --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none --load-only

    assert_eq "exit code" 0 "$LAST_EXIT"
    assert_not_called "the registry is not asked" "${args}.calls" \
        "^manifest inspect"
}

# The archive and the rosetta images publish one image for each network, so the
# network is part of the readable tag. The daemon image does not.
test_archive_tag_holds_the_network() {
    local args="${STUB_DIR}/archive.args"
    run_build "$args" \
        --service mina-archive --version 3.1.0 --network mainnet \
        --docker-registry testreg --deb-codename noble --deb-build-flags none

    assert_option_value "target" "$args" "--target" "mina-archive"
    assert_has_line "ubuntu base image" "$args" "image=ubuntu:noble"
    assert_has_line "readable tag" "$args" "testreg/mina-archive:3.1.0-mainnet"
    assert_has_line "hash tag" "$args" "testreg/mina-archive:abcdefg-noble-mainnet"
}

test_rosetta_tag_holds_the_network() {
    local args="${STUB_DIR}/rosetta.args"
    run_build "$args" \
        --service mina-rosetta --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    assert_option_value "target" "$args" "--target" "mina-rosetta"
    assert_has_line "readable tag" "$args" "testreg/mina-rosetta:3.1.0-devnet"
}

test_base_image_service() {
    local args="${STUB_DIR}/base.args"
    run_build "$args" \
        --service mina-base --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    assert_option_value "target" "$args" "--target" "base-deps"
    assert_has_line "tag" "$args" "testreg/mina-base:3.1.0"
}

test_hardfork_targets() {
    local args="${STUB_DIR}/hf.args"

    run_build "$args" \
        --service mina-daemon-legacy-hardfork --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none
    assert_option_value "legacy hardfork target" "$args" "--target" \
        "mina-daemon-prefork-genesis"

    run_build "$args" \
        --service mina-daemon-auto-hardfork --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none --deb-legacy-version 2.0.0
    assert_option_value "auto hardfork target" "$args" "--target" \
        "mina-daemon-auto-hardfork"
    assert_has_line "the legacy version reaches the build" "$args" \
        "deb_legacy_version=2.0.0"
    assert_has_line "the tag holds the network" "$args" \
        "testreg/mina-daemon-auto-hardfork:3.1.0-devnet"
}

# A *-configured or *-profiled service adds a layer on top of the image of
# another service. Its own tag uses MINA_DOCKER_TAG, because it holds the
# configuration of this commit. Here MINA_DOCKER_TAG is
# 3.0.0-test-branch-abcdefg-bullseye.
test_configured_service_uses_docker_tag_for_the_output() {
    local args="${STUB_DIR}/configured.args"
    run_build "$args" \
        --service mina-daemon-configured --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    assert_has_line "dockerfile" "$args" "dockerfiles/Dockerfile-install-config"
    assert_has_line "the version names the base image" "$args" "version=3.1.0"
    assert_has_line "output tag" "$args" \
        "testreg/mina-daemon:3.0.0-test-branch-abcdefg-bullseye-devnet"
}

test_profiled_service_uses_its_own_dockerfile() {
    local args="${STUB_DIR}/profiled.args"
    run_build "$args" \
        --service mina-daemon-profiled --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    assert_has_line "dockerfile" "$args" "dockerfiles/Dockerfile-install-profile"
    assert_has_line "output tag" "$args" \
        "testreg/mina-daemon:3.0.0-test-branch-abcdefg-bullseye-devnet-generic"
    # The hash tag already names the network, so the profile must not add it a
    # second time. It did, and the integration tests could not find the image:
    # they ask for "<githash>-<codename>-<network>-generic", which is also what
    # the readable tag above says.
    assert_has_line "hash tag names the network once" "$args" \
        "testreg/mina-daemon:abcdefg-bullseye-devnet-generic"
    assert_not_called "the network is not doubled" "$args" "devnet-devnet"

    # The debian package inside the image is a different name: there the
    # network is a prefix and the profile is part of the suffix, so
    # "mina-devnet-devnet-generic" is correct and must stay.
    assert_has_line "debian suffix keeps the profile" "$args" \
        "deb_suffix=devnet-generic"
}

# A lightnet profiled image has no "-generic", and its suffix is the same in
# both tags.
test_profiled_lightnet_suffix() {
    local args="${STUB_DIR}/profiled-lightnet.args"
    run_build "$args" \
        --service mina-daemon-profiled --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-profile lightnet --deb-build-flags none

    assert_has_line "readable tag" "$args" \
        "testreg/mina-daemon:3.0.0-test-branch-abcdefg-bullseye-lightnet"
    assert_has_line "hash tag" "$args" \
        "testreg/mina-daemon:abcdefg-bullseye-devnet-lightnet"
}

# Instrumented builds append to both suffixes, and the network still appears
# once in the hash tag.
test_profiled_instrumented_suffix() {
    local args="${STUB_DIR}/profiled-instrumented.args"
    run_build "$args" \
        --service mina-daemon-profiled --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags instrumented

    assert_has_line "readable tag" "$args" \
        "testreg/mina-daemon:3.0.0-test-branch-abcdefg-bullseye-devnet-generic-instrumented"
    assert_has_line "hash tag" "$args" \
        "testreg/mina-daemon:abcdefg-bullseye-devnet-generic-instrumented"
}

test_rosetta_configured_keeps_the_rosetta_name() {
    local args="${STUB_DIR}/rosconf.args"
    run_build "$args" \
        --service mina-rosetta-configured --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    assert_has_line "dockerfile" "$args" "dockerfiles/Dockerfile-install-config"
    assert_has_line "output tag" "$args" \
        "testreg/mina-rosetta:3.0.0-test-branch-abcdefg-bullseye-devnet"
}

test_toolchain_joins_the_stage_files() {
    local args="${STUB_DIR}/toolchain.args"
    run_build "$args" \
        --service mina-toolchain --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    assert_matches "a temporary Dockerfile holds the joined stages" "$args" \
        "^/tmp/Dockerfile-toolchain\."
    assert_has_line "the toolchain tag has no network" "$args" "testreg/mina-toolchain:3.1.0"
}

test_delegation_verifier() {
    local args="${STUB_DIR}/deleg.args"
    run_build "$args" \
        --service mina-delegation-verifier --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-build-flags none

    assert_has_line "dockerfile" "$args" \
        "dockerfiles/Dockerfile-delegation-stateless-verifier"
    assert_has_line "context" "$args" "dockerfiles/"
    assert_has_line "tag" "$args" "testreg/mina-delegation-verifier:3.1.0"
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
        "testreg/mina-daemon:3.1.0-generic-lightnet-instrumented"
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

test_base_image_for_each_codename() {
    local args="${STUB_DIR}/codename.args"
    local codename image
    for pair in "bullseye:debian:bullseye-slim" "focal:ubuntu:focal" \
                "jammy:ubuntu:jammy" "noble:ubuntu:noble"; do
        codename="${pair%%:*}"
        image="${pair#*:}"
        run_build "$args" \
            --service mina-daemon --version 3.1.0 --network devnet \
            --docker-registry testreg --deb-build-flags none --deb-codename "$codename"
        assert_has_line "$codename base image" "$args" "image=${image}"
    done
}

test_missing_input_stops_the_build() {
    local args="${STUB_DIR}/missing.args"

    run_build "$args" --version 3.1.0 --network devnet
    if [[ "$LAST_EXIT" -eq 0 ]]; then log_fail "no --service must stop the build"; else log_pass; fi

    run_build "$args" --service mina-daemon --network devnet
    if [[ "$LAST_EXIT" -eq 0 ]]; then log_fail "no --version must stop the build"; else log_pass; fi

    run_build "$args" --service not-a-service --version 3.1.0 --network devnet
    if [[ "$LAST_EXIT" -eq 0 ]]; then log_fail "an unknown service must stop the build"; else log_pass; fi

    run_build "$args" --service mina-daemon --version 3.1.0 --network devnet \
        --docker-registry testreg --deb-codename sid
    if [[ "$LAST_EXIT" -eq 0 ]]; then log_fail "an unknown codename must stop the build"; else log_pass; fi

    run_build "$args" --service mina-daemon-auto-hardfork --version 3.1.0 \
        --network devnet --docker-registry testreg
    if [[ "$LAST_EXIT" -eq 0 ]]; then
        log_fail "the auto hardfork build must stop without --deb-legacy-version"
    else
        log_pass
    fi
}

# Every stage file that build.sh joins into a Dockerfile must exist. This test
# finds a file that a rename or a deletion has lost.
test_stage_files_exist() {
    local f
    for f in \
        dockerfiles/stages/1-base-deps \
        dockerfiles/stages/daemon/2-mina-daemon \
        dockerfiles/stages/daemon/3-prefork-genesis \
        dockerfiles/stages/daemon/4-auto-hardfork \
        dockerfiles/stages/archive/2-mina-archive \
        dockerfiles/stages/rosetta/1-base-deps \
        dockerfiles/stages/rosetta/2-mina-rosetta \
        dockerfiles/toolchain/1-build-deps \
        dockerfiles/toolchain/2-opam-deps \
        dockerfiles/toolchain/3-toolchain \
        dockerfiles/Dockerfile-install-config \
        dockerfiles/Dockerfile-install-profile \
        dockerfiles/Dockerfile-delegation-stateless-verifier \
        dockerfiles/scripts/install-mina-debs.sh
    do
        assert_file_exists "$f" "${REPO_ROOT}/${f}"
    done
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

# DEFECT: the service check uses a substring match:
#   echo "${VALID_SERVICES[@]}" | grep -o "$SERVICE"
# So a partial name passes the check and the build stops later, at the "case"
# statement, with a message that is less clear.
test_DEFECT_a_partial_service_name_passes_the_check() {
    local args="${STUB_DIR}/partial.args"
    run_build "$args" --service mina-daemon-config --version 3.1.0 --network devnet \
        --docker-registry testreg

    if [[ "$LAST_EXIT" -eq 0 ]]; then
        log_fail "a partial service name must not build"
    else
        log_pass
    fi
    if grep -q "Unsupported service" "${args}.log"; then
        log_pass
    else
        log_fail "REPAIRED: the name check now refuses a partial name. Change this test."
    fi
}

# DEFECT: VALID_SERVICES holds four names that the "case" statement does not
# know, so they pass the check and then always stop the build. Delete them.
test_DEFECT_valid_services_holds_names_that_cannot_build() {
    local args="${STUB_DIR}/ghost.args"
    local service
    for service in mina-daemon-generic mina-rosetta-generic mina-tx-tools leaderboard; do
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

# DEFECT: two services point to a Dockerfile that is not in the repository. The
# applications were deleted, but the branches in build.sh stayed. Delete them.
test_DEFECT_two_services_point_to_a_dockerfile_that_is_absent() {
    assert_file_absent "delegation-backend" \
        "${REPO_ROOT}/dockerfiles/Dockerfile-delegation-backend"
    assert_file_absent "delegation-backend-toolchain" \
        "${REPO_ROOT}/dockerfiles/Dockerfile-delegation-backend-toolchain"
}

################################################################################
# Main
################################################################################

main() {
    setup_stub_docker

    # Behaviour
    run_test test_daemon_command
    run_test test_push_is_a_separate_docker_call
    run_test test_load_only_does_not_push
    run_test test_published_tag_is_not_overwritten
    run_test test_force_overwrite_pushes_over_a_published_tag
    run_test test_load_only_ignores_the_published_tag
    run_test test_archive_tag_holds_the_network
    run_test test_rosetta_tag_holds_the_network
    run_test test_base_image_service
    run_test test_hardfork_targets
    run_test test_configured_service_uses_docker_tag_for_the_output
    run_test test_profiled_service_uses_its_own_dockerfile
    run_test test_profiled_lightnet_suffix
    run_test test_profiled_instrumented_suffix
    run_test test_rosetta_configured_keeps_the_rosetta_name
    run_test test_toolchain_joins_the_stage_files
    run_test test_delegation_verifier
    run_test test_suffix_order_is_generic_lightnet_instrumented
    run_test test_arm64_gets_a_platform_suffix
    run_test test_base_image_for_each_codename
    run_test test_missing_input_stops_the_build
    run_test test_stage_files_exist

    # Known defects
    run_test test_DEFECT_network_has_no_working_default
    run_test test_DEFECT_a_partial_service_name_passes_the_check
    run_test test_DEFECT_valid_services_holds_names_that_cannot_build
    run_test test_DEFECT_two_services_point_to_a_dockerfile_that_is_absent

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

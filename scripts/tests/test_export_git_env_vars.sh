#!/bin/bash
set -uo pipefail

################################################################################
# Test suite for the pinned git environment.
#
# Usage:
#   bash scripts/tests/test_export_git_env_vars.sh
#
# The tests are black box: they source the scripts as a caller does and read
# the variables that come out. Two things are under test.
#
# scripts/export-git-env-vars.sh must take its git facts from
# MINA_GIT_ENV_FILE when one is named, and from the checkout when none is.
#
# buildkite/scripts/git-env/{pin,read_from_cache}.sh must fix one identity for
# a build, before any job that reads one runs, and inherit it from the app
# build when this build compiled nothing. That matters most for
# GITHASH_CONFIG, which names the genesis config the daemon auto-loads: derived
# from the wrapping job's own checkout it names the wrong commit and the
# package holds a config its daemon will not look for.
#
# Every test that goes down the deriving path sets OVERRIDE_TAG, which is what
# stops export-git-env-vars.sh running "git fetch --tags" over the network.
################################################################################

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILURES=()
CURRENT_TEST=""

log_pass() { TESTS_PASSED=$((TESTS_PASSED + 1)); }

log_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILURES+=("${CURRENT_TEST}: $1")
    echo "  FAIL: $1" >&2
}

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        log_pass
    else
        log_fail "${label}: expected '${expected}', got '${actual}'"
    fi
}

assert_nonzero_exit() {
    local label="$1" code="$2"
    if [[ "$code" -ne 0 ]]; then
        log_pass
    else
        log_fail "${label}: expected a non-zero exit, got 0"
    fi
}

run_test() {
    CURRENT_TEST="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    local before=${TESTS_FAILED}
    echo -n "TEST: ${CURRENT_TEST} ... "
    "$1" || true
    if [[ ${TESTS_FAILED} -eq ${before} ]]; then echo "OK"; else echo "FAILED"; fi
}

TMP_ROOT=""
setup()    { TMP_ROOT="$(mktemp -d)"; }
teardown() { [[ -n "$TMP_ROOT" && -d "$TMP_ROOT" ]] && rm -rf "$TMP_ROOT"; return 0; }

# Source the script in a subshell and print the variables asked for, one on
# each line. Sourcing it in this shell would leak its values into the next test.
# The exit code of the subshell comes back in LAST_EXIT.
LAST_EXIT=0
export_vars() {
    local script="$1"; shift
    local out
    out="$(cd "$REPO_ROOT" && "$BASH" -c '
        set -a
        # shellcheck disable=SC1090
        source "$1" >/dev/null 2>&1
        set +a
        shift
        for v in "$@"; do printf "%s\n" "${!v-}"; done
    ' _ "$script" "$@" 2>/dev/null)"
    LAST_EXIT=$?
    printf '%s' "$out"
}

write_pin() {
    cat > "$1" <<PIN
{
  "githash_config": "aaaaaaaa",
  "githash": "aaaaaaa",
  "gitbranch": "a-pinned-branch",
  "gittag": "9.9.9",
  "this_commit_tag": ""
}
PIN
}

################################################################################
# scripts/export-git-env-vars.sh
################################################################################

# With no pin, the git facts come from the checkout, as they always have.
test_no_pin_derives_from_the_checkout() {
    local head expected out
    head="$(cd "$REPO_ROOT" && git rev-parse --short=8 --verify HEAD)"
    expected="${head}"

    out="$(MINA_GIT_ENV_FILE="" OVERRIDE_TAG="1.2.3" BRANCH_NAME="a-branch" \
        export_vars ./scripts/export-git-env-vars.sh GITHASH_CONFIG GITTAG)"

    assert_eq "githash config comes from HEAD" "$expected" "$(sed -n 1p <<<"$out")"
    assert_eq "the tag override still applies" "1.2.3" "$(sed -n 2p <<<"$out")"
}

# With a pin, they come from the file, and NOT from the checkout.
test_a_pin_replaces_the_checkout() {
    local pin out
    pin="${TMP_ROOT}/git-env.json"
    write_pin "$pin"

    out="$(MINA_GIT_ENV_FILE="$pin" BRANCH_NAME="ignored-branch" \
        export_vars ./scripts/export-git-env-vars.sh \
        GITHASH_CONFIG GITHASH GITBRANCH GITTAG)"

    assert_eq "githash config" "aaaaaaaa" "$(sed -n 1p <<<"$out")"
    assert_eq "githash is the 7-character form" "aaaaaaa" "$(sed -n 2p <<<"$out")"
    # BRANCH_NAME must not win: the branch belongs to the pinned commit too.
    assert_eq "branch" "a-pinned-branch" "$(sed -n 3p <<<"$out")"
    assert_eq "tag" "9.9.9" "$(sed -n 4p <<<"$out")"
}

# The version is composed from the pinned facts, but the codename stays the
# job's own -- one app build is packaged for every codename.
test_the_codename_is_not_pinned() {
    local pin out
    pin="${TMP_ROOT}/git-env.json"
    write_pin "$pin"

    out="$(MINA_GIT_ENV_FILE="$pin" SKIP_GITBRANCH=1 MINA_DEB_CODENAME=bookworm \
        export_vars ./scripts/export-git-env-vars.sh MINA_DEB_VERSION MINA_DOCKER_TAG)"

    assert_eq "version" "9.9.9-aaaaaaa" "$(sed -n 1p <<<"$out")"
    assert_eq "docker tag carries this job's codename" \
        "9.9.9-aaaaaaa-bookworm" "$(sed -n 2p <<<"$out")"
}

# An override is the escape hatch it has always been, and it outranks the pin.
test_an_override_outranks_the_pin() {
    local pin out
    pin="${TMP_ROOT}/git-env.json"
    write_pin "$pin"

    out="$(MINA_GIT_ENV_FILE="$pin" OVERRIDE_TAG="7.7.7" OVERRIDE_GITHASH="bbbbbbbb" \
        export_vars ./scripts/export-git-env-vars.sh GITTAG GITHASH_CONFIG)"

    assert_eq "tag" "7.7.7" "$(sed -n 1p <<<"$out")"
    assert_eq "githash config" "bbbbbbbb" "$(sed -n 2p <<<"$out")"
}

# A pin that cannot be read is a fault. Falling back to the checkout would put
# back the mismatch the pin exists to prevent, and say nothing about it.
test_an_unreadable_pin_is_an_error() {
    MINA_GIT_ENV_FILE="${TMP_ROOT}/not-here.json" \
        export_vars ./scripts/export-git-env-vars.sh GITTAG >/dev/null
    assert_nonzero_exit "missing file" "$LAST_EXIT"
}

# So is a pin that is missing a field this script needs.
test_an_incomplete_pin_is_an_error() {
    local pin="${TMP_ROOT}/partial.json"
    printf '{\n  "githash_config": "aaaaaaaa"\n}\n' > "$pin"

    MINA_GIT_ENV_FILE="$pin" export_vars ./scripts/export-git-env-vars.sh GITTAG >/dev/null
    assert_nonzero_exit "no gittag in the file" "$LAST_EXIT"
}

################################################################################
# The CI cache round trip
################################################################################

# What the prepare step pins is what every later job reads back.
test_the_pin_survives_the_cache() {
    local cache="${TMP_ROOT}/cache" dest="${TMP_ROOT}/fetched" out head
    mkdir -p "$cache" "$dest"
    head="$(cd "$REPO_ROOT" && git rev-parse --short=8 --verify HEAD)"

    ( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="a-build" BUILDKITE_BRANCH="a-branch" \
      OVERRIDE_TAG="4.5.6" \
      ./buildkite/scripts/git-env/pin.sh ) >/dev/null 2>&1
    assert_eq "the pin succeeds" "0" "$?"

    local fetched
    fetched="$( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="a-build" \
      ./buildkite/scripts/git-env/read_from_cache.sh "$dest" 2>/dev/null )"
    assert_eq "the reader finds it" "${dest}/git-env.json" "$fetched"

    out="$(MINA_GIT_ENV_FILE="$fetched" \
        export_vars ./scripts/export-git-env-vars.sh GITTAG GITHASH_CONFIG)"
    assert_eq "the tag round trips" "4.5.6" "$(sed -n 1p <<<"$out")"
    assert_eq "the githash round trips" "$head" "$(sed -n 2p <<<"$out")"
}

# A packaging build compiles nothing, so it takes the identity of the app build
# it is wrapping and copies it into its own root -- where every one of its own
# jobs then finds it, without any of them knowing where the binaries came from.
test_a_packaging_build_inherits_the_apps_identity() {
    local cache="${TMP_ROOT}/cache2" dest="${TMP_ROOT}/fetched2" fetched out
    mkdir -p "$cache" "$dest"

    ( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="the-app-build" BUILDKITE_BRANCH="a-branch" \
      OVERRIDE_TAG="4.5.6" \
      ./buildkite/scripts/git-env/pin.sh ) >/dev/null 2>&1

    # A different commit is checked out here; it must not be what comes out.
    ( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="the-packaging-build" \
      MINA_APPS_CACHE_ROOT="the-app-build" BUILDKITE_BRANCH="another-branch" \
      OVERRIDE_TAG="9.9.9" \
      ./buildkite/scripts/git-env/pin.sh ) >/dev/null 2>&1
    assert_eq "the inheriting pin succeeds" "0" "$?"

    fetched="$( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="the-packaging-build" \
      ./buildkite/scripts/git-env/read_from_cache.sh "$dest" 2>/dev/null )"
    assert_eq "the packaging build has its own copy" "${dest}/git-env.json" "$fetched"

    out="$(MINA_GIT_ENV_FILE="$fetched" export_vars ./scripts/export-git-env-vars.sh GITTAG)"
    assert_eq "it describes the app build, not this checkout" "4.5.6" "$out"
}

# Pinning twice in one build must not move the identity: the second stage of a
# release pipeline uploads prepare again, and it has to keep what stage one set.
test_a_second_stage_keeps_the_first_pin() {
    local cache="${TMP_ROOT}/cache3" dest="${TMP_ROOT}/fetched3" fetched out
    mkdir -p "$cache" "$dest"

    for tag in 4.5.6 9.9.9; do
        ( cd "$REPO_ROOT" && \
          CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="a-build" BUILDKITE_BRANCH="a-branch" \
          OVERRIDE_TAG="$tag" \
          ./buildkite/scripts/git-env/pin.sh ) >/dev/null 2>&1
    done

    fetched="$( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="a-build" \
      ./buildkite/scripts/git-env/read_from_cache.sh "$dest" 2>/dev/null )"
    out="$(MINA_GIT_ENV_FILE="$fetched" export_vars ./scripts/export-git-env-vars.sh GITTAG)"
    assert_eq "the first pin stands" "4.5.6" "$out"
}

# An artifact run started with --from is told which build to take its binaries
# and packages from through BUILDKITE_PIPELINE_FROM_BUILD, and that build's
# commit is the one to describe. Resolved here so no entrypoint has to.
test_from_build_is_inherited_like_a_read_root() {
    local cache="${TMP_ROOT}/cache-from" dest="${TMP_ROOT}/fetched-from" fetched out
    mkdir -p "$cache" "$dest"

    ( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="the-source-build" BUILDKITE_BRANCH="a-branch" \
      OVERRIDE_TAG="4.5.6" \
      ./buildkite/scripts/git-env/pin.sh ) >/dev/null 2>&1

    ( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="the-artifact-run" \
      BUILDKITE_PIPELINE_FROM_BUILD="the-source-build" BUILDKITE_BRANCH="another-branch" \
      OVERRIDE_TAG="9.9.9" \
      ./buildkite/scripts/git-env/pin.sh ) >/dev/null 2>&1
    assert_eq "the inheriting pin succeeds" "0" "$?"

    fetched="$( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="the-artifact-run" \
      ./buildkite/scripts/git-env/read_from_cache.sh "$dest" 2>/dev/null )"
    out="$(MINA_GIT_ENV_FILE="$fetched" export_vars ./scripts/export-git-env-vars.sh GITTAG)"
    assert_eq "it describes the build it took its artifacts from" "4.5.6" "$out"
}

# An entrypoint that renders a pipeline writes it to standard output and is
# invoked as "<entrypoint>.sh | buildkite-agent pipeline upload", so one line
# on standard output from the pin would be uploaded as part of the pipeline.
test_the_pin_says_nothing_on_standard_output() {
    local cache="${TMP_ROOT}/cache-quiet" out
    mkdir -p "$cache"

    # A fresh pin, which is the noisiest path: it derives and writes.
    out="$( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="a-build" BUILDKITE_BRANCH="a-branch" \
      OVERRIDE_TAG="4.5.6" \
      ./buildkite/scripts/git-env/pin.sh 2>/dev/null )"
    assert_eq "nothing on stdout when pinning" "" "$out"

    # And again, now that it is already pinned.
    out="$( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="a-build" BUILDKITE_BRANCH="a-branch" \
      OVERRIDE_TAG="4.5.6" \
      ./buildkite/scripts/git-env/pin.sh 2>/dev/null )"
    assert_eq "nothing on stdout when already pinned" "" "$out"

    # And when inheriting.
    out="$( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="another-build" \
      MINA_APPS_CACHE_ROOT="a-build" BUILDKITE_BRANCH="a-branch" OVERRIDE_TAG="4.5.6" \
      ./buildkite/scripts/git-env/pin.sh 2>/dev/null )"
    assert_eq "nothing on stdout when inheriting" "" "$out"
}

# Being told the binaries come from elsewhere, and finding no identity there,
# is a fault. Deriving from this checkout instead is the exact mistake that
# puts the wrong config_<hash>.json into a package, and it would say nothing.
test_wrapping_an_unpinned_build_is_an_error() {
    local cache="${TMP_ROOT}/cache4"
    mkdir -p "$cache"

    ( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="the-packaging-build" \
      MINA_APPS_CACHE_ROOT="a-build-that-never-pinned" BUILDKITE_BRANCH="a-branch" \
      OVERRIDE_TAG="1.1.1" \
      ./buildkite/scripts/git-env/pin.sh ) >/dev/null 2>&1
    assert_nonzero_exit "no identity to inherit" "$?"
}

# Nothing pinned is an ordinary outcome, not a failure: plenty of callers run
# where there is no cache at all.
test_a_cache_without_a_pin_is_not_an_error() {
    local cache="${TMP_ROOT}/empty" dest="${TMP_ROOT}/fetched5"
    mkdir -p "$cache" "$dest"

    ( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="a-build" \
      ./buildkite/scripts/git-env/read_from_cache.sh "$dest" ) >/dev/null 2>&1
    assert_nonzero_exit "the reader reports the miss" "$?"

    local out
    out="$( cd "$REPO_ROOT" && \
      CACHE_BASE_URL="$cache" BUILDKITE_BUILD_ID="a-build" BUILDKITE_BRANCH="a-branch" \
      OVERRIDE_TAG="1.1.1" "$BASH" -c '
        source ./buildkite/scripts/export-git-env-vars.sh >/dev/null 2>&1
        printf "%s\n" "$GITTAG"' 2>/dev/null )"
    assert_eq "the wrapper still works" "1.1.1" "$out"
}

################################################################################

main() {
    setup

    run_test test_no_pin_derives_from_the_checkout
    run_test test_a_pin_replaces_the_checkout
    run_test test_the_codename_is_not_pinned
    run_test test_an_override_outranks_the_pin
    run_test test_an_unreadable_pin_is_an_error
    run_test test_an_incomplete_pin_is_an_error
    run_test test_the_pin_survives_the_cache
    run_test test_a_packaging_build_inherits_the_apps_identity
    run_test test_a_second_stage_keeps_the_first_pin
    run_test test_from_build_is_inherited_like_a_read_root
    run_test test_the_pin_says_nothing_on_standard_output
    run_test test_wrapping_an_unpinned_build_is_an_error
    run_test test_a_cache_without_a_pin_is_not_an_error

    teardown

    echo ""
    echo "========================================"
    echo "Results: ${TESTS_RUN} tests, ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"
    echo "========================================"

    if [[ ${#FAILURES[@]} -gt 0 ]]; then
        echo ""
        echo "Failures:"
        for f in "${FAILURES[@]}"; do echo "  - ${f}"; done
    fi

    echo ""
    if [[ ${TESTS_FAILED} -gt 0 ]]; then exit 1; fi
    echo "All tests passed."
}

main "$@"

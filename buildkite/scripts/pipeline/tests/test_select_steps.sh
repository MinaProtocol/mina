#!/bin/bash
set -euo pipefail

################################################################################
# Tests for select_steps.sh
#
# Usage: bash buildkite/scripts/pipeline/tests/test_select_steps.sh
#
# The tests run against small rendered pipelines written in a temporary
# directory, not against the real ones, so they do not change when a job is
# added and they need no dhall.
#
# The fixture has the shape the real pipelines have: an apps job that another
# job depends on, a debian step that every image step depends on, and an image
# that is FROM another image.
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELECT="${SCRIPT_DIR}/../select_steps.sh"

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

assert_has() {
    local label="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qFx -- "$needle"; then
        log_pass
    else
        log_fail "${label}: '${needle}' is not in the result"
    fi
}

assert_has_not() {
    local label="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qFx -- "$needle"; then
        log_fail "${label}: '${needle}' must not be in the result"
    else
        log_pass
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

################################################################################
# Fixture
################################################################################

JOBS_DIR=""

setup_fixture() {
    JOBS_DIR="$(mktemp -d)"

    cat > "${JOBS_DIR}/Apps.yml" <<'YAML'
spec:
  name: Apps
  path: Release
pipeline:
  steps:
    - key: _Apps-build-apps
      label: build apps
YAML

    cat > "${JOBS_DIR}/Package.yml" <<'YAML'
spec:
  name: Package
  path: Release
pipeline:
  steps:
    - key: _Package-build-deb-pkg
      label: debians
      depends_on:
        - step: _Apps-build-apps
    - key: _Package-daemon_apps_only-devnet-docker-image
      label: daemon apps only
      depends_on:
        - step: _Package-build-deb-pkg
    - key: _Package-daemon_config-devnet-docker-image
      label: daemon config
      depends_on:
        - step: _Package-build-deb-pkg
        - step: _Package-daemon_apps_only-devnet-docker-image
    - key: _Package-archive-devnet-docker-image
      label: archive
      depends_on:
        - step: _Package-build-deb-pkg
YAML
}

teardown_fixture() {
    [[ -n "$JOBS_DIR" && -d "$JOBS_DIR" ]] && rm -rf "$JOBS_DIR"
    return 0
}

select_keys() {
    "$SELECT" --jobs "$JOBS_DIR" --format keys --quiet "$@"
}

################################################################################
# Tests
################################################################################

# A step that is FROM another image, in a job that is built from an other job,
# must bring both with it.
test_closure_reaches_through_jobs() {
    local out
    out="$(select_keys --select 'daemon_config-devnet-docker-image')"

    assert_has "the step asked for" "$out" "_Package-daemon_config-devnet-docker-image"
    assert_has "the image it is FROM" "$out" "_Package-daemon_apps_only-devnet-docker-image"
    assert_has "the debians it installs" "$out" "_Package-build-deb-pkg"
    assert_has "the apps of the other job" "$out" "_Apps-build-apps"
    assert_eq "nothing else" "4" "$(echo "$out" | wc -l)"
}

# Nothing that is not needed comes with it.
test_only_what_is_needed() {
    local out
    out="$(select_keys --select 'archive-devnet-docker-image')"

    assert_has "the step asked for" "$out" "_Package-archive-devnet-docker-image"
    assert_has "the debians" "$out" "_Package-build-deb-pkg"
    assert_has "the apps" "$out" "_Apps-build-apps"
    assert_has_not "no daemon image" "$out" "_Package-daemon_config-devnet-docker-image"
    assert_has_not "no apps only image" "$out" "_Package-daemon_apps_only-devnet-docker-image"
}

# This is the invariant the whole script exists for: a step that waits for a
# step outside the run set waits for ever.
test_no_step_waits_for_a_step_outside_the_run_set() {
    local out
    out="$(select_keys --select '*docker-image')"

    local key deps dep
    while IFS= read -r key; do
        deps="$(yq -r "[.pipeline.steps[]? | select(.key == \"${key}\") | .depends_on[]?.step] | .[]" \
            "${JOBS_DIR}"/*.yml 2>/dev/null || true)"
        while IFS= read -r dep; do
            [[ -z "$dep" ]] && continue
            if echo "$out" | grep -qFx -- "$dep"; then
                log_pass
            else
                log_fail "'${key}' waits for '${dep}', which is not in the run set"
            fi
        done <<< "$deps"
    done <<< "$out"
}

test_a_pattern_may_hold_a_star() {
    local out
    out="$(select_keys --select 'daemon_*-devnet-docker-image')"

    assert_has "apps only" "$out" "_Package-daemon_apps_only-devnet-docker-image"
    assert_has "config" "$out" "_Package-daemon_config-devnet-docker-image"
    assert_has_not "not the archive" "$out" "_Package-archive-devnet-docker-image"
}

# The name of the job holds the codename and the architecture, so the whole key
# is how one asks for a step of one pipeline only.
test_the_whole_key_chooses_one_job() {
    local out
    out="$(select_keys --select '_Package-archive-devnet-docker-image')"
    assert_has "the step" "$out" "_Package-archive-devnet-docker-image"
    assert_eq "the step and what it needs" "3" "$(echo "$out" | wc -l)"
}

test_more_than_one_select_adds_up() {
    local out
    out="$(select_keys --select 'archive-devnet-docker-image' --select 'daemon_apps_only-devnet-docker-image')"
    assert_has "the first" "$out" "_Package-archive-devnet-docker-image"
    assert_has "the second" "$out" "_Package-daemon_apps_only-devnet-docker-image"
}

test_formats() {
    local files plan
    files="$("$SELECT" --jobs "$JOBS_DIR" --format files --quiet --select 'archive-devnet-docker-image')"
    assert_has "the job of the step" "$files" "${JOBS_DIR}/Package.yml"
    assert_has "the job it depends on" "$files" "${JOBS_DIR}/Apps.yml"
    assert_eq "each file one time" "2" "$(echo "$files" | wc -l)"

    plan="$("$SELECT" --jobs "$JOBS_DIR" --format plan --quiet --select 'archive-devnet-docker-image')"
    assert_eq "the plan holds a file and a key" "2" "$(echo "$plan" | head -1 | awk -F'\t' '{print NF}')"
}

test_a_pattern_that_matches_nothing_stops() {
    local out status=0
    out="$("$SELECT" --jobs "$JOBS_DIR" --format keys --select 'no-such-step' 2>&1)" || status=$?
    assert_eq "exit code" "1" "$status"
    if echo "$out" | grep -q "archive-devnet-docker-image"; then
        log_pass
    else
        log_fail "the message must write the keys that do exist"
    fi
}

# A set is only sugar: it must give exactly what its patterns give.
test_a_set_is_the_same_as_its_patterns() {
    local by_set by_pattern
    by_set="$("$SELECT" --jobs "$JOBS_DIR" --format keys --quiet --set all)"
    by_pattern="$(select_keys --select '*-docker-image')"
    assert_eq "a set and its pattern agree" "$by_pattern" "$by_set"
}

test_a_set_that_is_not_known_stops() {
    local out status=0
    out="$("$SELECT" --jobs "$JOBS_DIR" --format keys --set no-such-set 2>&1)" || status=$?
    assert_eq "exit code" "2" "$status"
    if echo "$out" | grep -q "automode"; then
        log_pass
    else
        log_fail "the message must write the sets that do exist"
    fi
}

test_the_sets_can_be_listed() {
    local out
    out="$("$SELECT" --list-sets)"
    if echo "$out" | grep -q "automode"; then log_pass; else log_fail "automode is missing"; fi
    if echo "$out" | grep -q "docker-image"; then log_pass; else log_fail "the patterns are missing"; fi
}

# The layer decides which side of a set is read. A set names an artifact, and an
# artifact can appear in one layer and not the other.
test_the_layer_chooses_the_side_of_a_set() {
    local out status=0

    out="$(select_keys --layer debian --set archive)"
    assert_eq "the debian layer asks for the packaging step" \
        "_Package-build-deb-pkg" "$(echo "$out" | grep -c 'build-deb-pkg' > /dev/null && echo '_Package-build-deb-pkg')"

    # prefork has packages and no image.
    "$SELECT" --jobs "$JOBS_DIR" --format keys --quiet --layer docker --set prefork > /dev/null 2>&1 || status=$?
    assert_eq "a set with no image stops" "2" "$status"

    status=0
    "$SELECT" --jobs "$JOBS_DIR" --format keys --quiet --layer debian --set prefork > /dev/null 2>&1 || status=$?
    assert_eq "the same set is fine in the debian layer" "0" "$status"
}

test_the_debian_patterns_can_be_printed() {
    local out
    out="$("$SELECT" --print-debians --set prefork)"
    if echo "$out" | grep -q "prefork_.*_genesis_ledger"; then
        log_pass
    else
        log_fail "the genesis ledger package is missing from '${out}'"
    fi
}

# The filters are put on the steps that were ASKED for, never on the ones added
# because something needs them: keeping to one job must not throw away the
# debian step that the chosen image is built from.
test_a_filter_never_removes_a_dependency() {
    local out
    out="$(select_keys --select '*-docker-image' --job-include 'Package')"
    assert_has "the image asked for" "$out" "_Package-archive-devnet-docker-image"
    assert_has "the debians it needs" "$out" "_Package-build-deb-pkg"
    assert_has "the apps job, whose name the filter rejects" "$out" "_Apps-build-apps"
}

test_a_filter_can_exclude_a_job() {
    local out status=0
    out="$("$SELECT" --jobs "$JOBS_DIR" --format keys --quiet \
        --select '*-docker-image' --job-exclude 'Package' 2>&1)" || status=$?
    assert_eq "nothing is left to choose" "1" "$status"
}

test_a_key_filter_narrows_the_network() {
    local out
    out="$(select_keys --select '*-docker-image' --key-include '*-devnet-*')"
    assert_has "the devnet image" "$out" "_Package-archive-devnet-docker-image"
}

# One flag is one axis: the globs inside it are alternatives, and two flags must
# BOTH hold. Getting this wrong turns "the arm64 build of bookworm" into
# "anything that is bookworm or arm64", which is a much bigger build.
test_two_filters_must_both_hold() {
    local out status=0

    out="$(select_keys --select '*-docker-image' --job-include 'Package,Nothing')"
    assert_has "an alternative inside one flag is enough" "$out" "_Package-archive-devnet-docker-image"

    # Package matches the first flag and not the second, so nothing is left.
    "$SELECT" --jobs "$JOBS_DIR" --format keys --quiet \
        --select '*-docker-image' --job-include 'Package' --job-include 'Nothing' \
        > /dev/null 2>&1 || status=$?
    assert_eq "two flags must both hold" "1" "$status"
}

test_wrong_arguments_stop() {
    local status

    status=0
    "$SELECT" --format keys --select 'x' > /dev/null 2>&1 || status=$?
    assert_eq "no --jobs" "2" "$status"

    status=0
    "$SELECT" --jobs "$JOBS_DIR" > /dev/null 2>&1 || status=$?
    assert_eq "no --select" "2" "$status"

    status=0
    "$SELECT" --jobs "$JOBS_DIR" --select 'x' --format nope > /dev/null 2>&1 || status=$?
    assert_eq "a format that is not known" "2" "$status"

    status=0
    "$SELECT" --jobs /no/such/dir --select 'x' > /dev/null 2>&1 || status=$?
    assert_eq "a directory that is not there" "2" "$status"
}

################################################################################

main() {
    command -v yq > /dev/null 2>&1 || { echo "yq is needed" >&2; exit 2; }

    setup_fixture

    run_test test_closure_reaches_through_jobs
    run_test test_only_what_is_needed
    run_test test_no_step_waits_for_a_step_outside_the_run_set
    run_test test_a_pattern_may_hold_a_star
    run_test test_the_whole_key_chooses_one_job
    run_test test_more_than_one_select_adds_up
    run_test test_formats
    run_test test_a_pattern_that_matches_nothing_stops
    run_test test_a_set_is_the_same_as_its_patterns
    run_test test_a_set_that_is_not_known_stops
    run_test test_the_sets_can_be_listed
    run_test test_the_layer_chooses_the_side_of_a_set
    run_test test_the_debian_patterns_can_be_printed
    run_test test_a_filter_never_removes_a_dependency
    run_test test_a_filter_can_exclude_a_job
    run_test test_a_key_filter_narrows_the_network
    run_test test_two_filters_must_both_hold
    run_test test_wrong_arguments_stop

    teardown_fixture

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
    if [[ ${TESTS_FAILED} -gt 0 ]]; then exit 1; else echo "All tests passed."; exit 0; fi
}

main "$@"

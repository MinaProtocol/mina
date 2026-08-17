#!/bin/bash
set -euo pipefail

################################################################################
# Tests for how run-selection.sh reads what was asked for.
#
# Usage: bash buildkite/scripts/pipeline/tests/test_run_selection_env.sh
#
# The patterns reach a real build in the environment, never in a dhall
# expression, so what the environment does is worth pinning down: it has to
# drive the run exactly as the flags do, and a flag has to win over it.
#
# Every run is a dry run, so nothing reaches buildkite-agent.
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_SELECTION="${SCRIPT_DIR}/../../entrypoints/run-selection.sh"

RUN=0; PASSED=0; FAILED=0; FAILURES=()

check() {
    local label="$1" expected="$2" actual="$3"
    RUN=$((RUN + 1))
    if [[ "$expected" == "$actual" ]]; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        FAILURES+=("${label}: expected '${expected}', got '${actual}'")
        echo "  FAIL ${label}: expected '${expected}', got '${actual}'" >&2
    fi
}

JOBS_DIR="$(mktemp -d)"
trap 'rm -rf "$JOBS_DIR"' EXIT

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
      command:
        - echo "-- Running: ( ./buildkite/scripts/debian/build-from-cache.sh bullseye logproc archive_devnet ) --"
        - docker run --rm image bash -c "./buildkite/scripts/debian/build-from-cache.sh bullseye logproc archive_devnet"
    - key: _Package-daemon_config-devnet-docker-image
      label: daemon config
      depends_on:
        - step: _Package-build-deb-pkg
    - key: _Package-archive-devnet-docker-image
      label: archive
      depends_on:
        - step: _Package-build-deb-pkg
YAML

# Runs with a clean environment, so a variable of the shell running the tests
# cannot decide the answer. VARS holds the environment settings, ARGS the flags.
run_selection() {
    local -a vars=() args=()
    local seen_args=false
    for item in "$@"; do
        if [[ "$item" == "--" ]]; then seen_args=true; continue; fi
        if [[ "$seen_args" == true ]]; then args+=("$item"); else vars+=("$item"); fi
    done
    env -u BUILDKITE_PIPELINE_SELECTION -u BUILDKITE_PIPELINE_DEB_SELECTION \
        "${vars[@]}" "$RUN_SELECTION" --jobs "$JOBS_DIR" --dry-run "${args[@]}" 2>&1
}

# The jobs that would be uploaded, one per line, in a fixed order.
uploaded_jobs() { grep -o 'would upload [A-Za-z]*' | sed 's/would upload //' | sort | tr '\n' ' '; }

# The step keys that would be uploaded, in a fixed order. Read from the upload
# lines only, so a key echoed in the log of what was asked for cannot count.
run_set() {
    grep 'would upload' | grep -o '_[A-Za-z]*-[A-Za-z0-9_-]*' | sort -u | tr '\n' ' '
}

echo "TEST: the environment drives the run just as --selection does"
from_env="$(run_selection BUILDKITE_PIPELINE_SELECTION='archive-devnet-docker-image' | run_set)"
from_flag="$(run_selection -- --selection 'archive-devnet-docker-image' | run_set)"
check "the environment picks a run set" "1" "$([[ -n "$from_env" ]] && echo 1 || echo 0)"
check "the flag picks the same one" "$from_flag" "$from_env"

echo "TEST: the dependency of a chosen step is added, from the environment too"
out="$(run_selection BUILDKITE_PIPELINE_SELECTION='archive-devnet-docker-image')"
check "both jobs are uploaded" "Apps Package " "$(echo "$out" | uploaded_jobs)"
check "the run set is the image, its debians and the apps" \
    "_Apps-build-apps _Package-archive-devnet-docker-image _Package-build-deb-pkg " \
    "$(echo "$out" | run_set)"

echo "TEST: a flag wins over the environment"
out="$(run_selection BUILDKITE_PIPELINE_SELECTION='archive-devnet-docker-image' \
       -- --selection 'daemon_config-devnet-docker-image')"
check "the flag decides" \
    "_Apps-build-apps _Package-build-deb-pkg _Package-daemon_config-devnet-docker-image " \
    "$(echo "$out" | run_set)"

echo "TEST: packages alone, out of the environment, ask for the debian step"
out="$(run_selection BUILDKITE_PIPELINE_DEB_SELECTION='logproc' -- --debug)"
check "only the debian step and what it needs" \
    "_Apps-build-apps _Package-build-deb-pkg " \
    "$(echo "$out" | run_set)"
check "the package list is narrowed in both places" "2" \
    "$(echo "$out" | grep -c 'build-from-cache.sh bullseye logproc')"
check "the package that was not asked for is dropped, and said so" "1" \
    "$(echo "$out" | grep -c 'not built: archive_devnet')"
check "and it is in no command" "0" \
    "$(echo "$out" | grep 'build-from-cache.sh' | grep -c 'archive_devnet')"

echo "TEST: a name that is a set is read as a set, not as a pattern"
# 'dockers' names a set. As a pattern it would match no key at all, so this
# passes only if the name was expanded.
out="$(run_selection BUILDKITE_PIPELINE_SELECTION='dockers')"
check "it says which name was read as a set" "1" \
    "$(echo "$out" | grep -c 'Read as a set of steps: dockers')"
check "both images are chosen" \
    "_Apps-build-apps _Package-archive-devnet-docker-image _Package-build-deb-pkg _Package-daemon_config-devnet-docker-image " \
    "$(echo "$out" | run_set)"

echo "TEST: a set and a pattern add up"
out="$(run_selection BUILDKITE_PIPELINE_SELECTION='debians,archive-devnet-docker-image')"
check "the set is named" "1" "$(echo "$out" | grep -c 'Read as a set of steps: debians')"
check "the pattern is kept too" \
    "_Apps-build-apps _Package-archive-devnet-docker-image _Package-build-deb-pkg " \
    "$(echo "$out" | run_set)"

echo "TEST: a name that is no set is still a pattern, and a wrong one stops"
status=0
run_selection BUILDKITE_PIPELINE_SELECTION='dockrs' > /dev/null 2>&1 || status=$?
check "exit code" "1" "$status"

echo "TEST: with neither, the script stops rather than building everything"
status=0
run_selection > /dev/null 2>&1 || status=$?
check "exit code" "2" "$status"

echo "TEST: a pattern that matches nothing stops"
status=0
run_selection BUILDKITE_PIPELINE_SELECTION='no_such_step' > /dev/null 2>&1 || status=$?
check "exit code" "1" "$status"

echo
echo "========================================"
echo "Checks run:    ${RUN}"
echo "Checks passed: ${PASSED}"
if [[ "$FAILED" -gt 0 ]]; then
    echo "Checks failed: ${FAILED}"
    printf '  %s\n' "${FAILURES[@]}"
    exit 1
fi
echo "All checks passed."

#!/bin/bash
set -euo pipefail

# Tests for narrow_debian_tokens.sh
#
# Usage: bash buildkite/scripts/pipeline/tests/test_narrow_debian_tokens.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NARROW="${SCRIPT_DIR}/../narrow_debian_tokens.sh"

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

# A step whose token list is written twice, as the real pipelines write it: once
# in the line the log shows, and once in the command that runs.
fixture() {
    cat <<'YAML'
steps:
  - key: _Job-build-deb-pkg
    command:
      - echo "-- Running: ( ./buildkite/scripts/debian/build-from-cache.sh bullseye logproc archive_devnet daemon_devnet_prefork prefork_devnet_genesis_ledger ) --"
      - docker run --rm image bash -c "./buildkite/scripts/debian/build-from-cache.sh bullseye logproc archive_devnet daemon_devnet_prefork prefork_devnet_genesis_ledger"
      - ./buildkite/scripts/debian/write_to_cache.sh bullseye
YAML
}

echo "TEST: a pattern keeps only what matches"
out="$(fixture | "$NARROW" 'prefork_*' 'daemon_*_prefork' 2>/dev/null)"
check "kept tokens" "2" "$(echo "$out" | grep -o 'build-from-cache.sh bullseye[a-z0-9_ ]*' | head -1 | grep -o '[a-z0-9_]*prefork[a-z0-9_]*' | wc -l)"
check "logproc is gone" "0" "$(echo "$out" | grep -c 'bullseye logproc' || true)"

echo "TEST: BOTH places are rewritten, so the log matches what runs"
count="$(echo "$out" | grep -c 'build-from-cache.sh bullseye daemon_devnet_prefork prefork_devnet_genesis_ledger')"
check "two occurrences" "2" "$count"

echo "TEST: the rest of the pipeline is untouched"
check "write_to_cache stays" "1" "$(echo "$out" | grep -c 'write_to_cache.sh bullseye')"
check "the key stays" "1" "$(echo "$out" | grep -c '_Job-build-deb-pkg')"

echo "TEST: a pattern that matches nothing stops, it does not build everything"
status=0
fixture | "$NARROW" 'no_such_package' > /dev/null 2>&1 || status=$?
check "exit code" "1" "$status"
msg="$(fixture | "$NARROW" 'no_such_package' 2>&1 >/dev/null || true)"
check "the message lists what exists" "1" "$(echo "$msg" | grep -c 'archive_devnet')"

echo "TEST: a pipeline with no debian call stops"
status=0
echo "steps: []" | "$NARROW" 'logproc' > /dev/null 2>&1 || status=$?
check "exit code" "1" "$status"

echo "TEST: a variant that holds a dash is narrowed too"
# bullseye-instrumented and bullseye-arm64 are real tree variants.
dashed="$(fixture | sed 's/build-from-cache.sh bullseye /build-from-cache.sh bullseye-instrumented /g')"
status=0
out="$(echo "$dashed" | "$NARROW" 'logproc' 2>/dev/null)" || status=$?
check "exit code" "0" "$status"
check "two occurrences" "2" "$(echo "$out" | grep -c 'build-from-cache.sh bullseye-instrumented logproc"\?')"
check "archive_devnet is gone" "0" "$(echo "$out" | grep -c 'archive_devnet' || true)"

echo "TEST: nothing is written when the run has to stop"
out="$(fixture | "$NARROW" 'no_such_package' 2>/dev/null || true)"
check "empty stdout" "" "$out"

echo "TEST: no pattern at all is refused"
status=0
fixture | "$NARROW" > /dev/null 2>&1 || status=$?
check "exit code" "2" "$status"

echo ""
echo "Results: ${RUN} checks, ${PASSED} passed, ${FAILED} failed"
if [[ ${FAILED} -gt 0 ]]; then
    printf '  - %s\n' "${FAILURES[@]}"
    exit 1
fi
echo "All tests passed."

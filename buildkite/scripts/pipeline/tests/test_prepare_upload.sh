#!/bin/bash
set -euo pipefail

# Tests for prepare_upload.sh
#
# Usage: bash buildkite/scripts/pipeline/tests/test_prepare_upload.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREPARE="${SCRIPT_DIR}/../prepare_upload.sh"

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

# prepare_upload.sh calls the upload.sh that sits beside it, so the script is
# copied next to a stub that only writes down what it was handed. Nothing
# reaches buildkite-agent.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

cp "$PREPARE" "${SANDBOX}/prepare_upload.sh"
cat > "${SANDBOX}/upload.sh" <<'STUB'
#!/usr/bin/env bash
echo "UPLOADED: $1"
STUB
chmod +x "${SANDBOX}/upload.sh" "${SANDBOX}/prepare_upload.sh"

MONOREPO_EXPR='(./buildkite/src/Monorepo.dhall) { selection=Triaged }'

run_prepare() {
    env -u BUILDKITE_PIPELINE_SELECTION -u BUILDKITE_PIPELINE_DEB_SELECTION \
        "$@" "${SANDBOX}/prepare_upload.sh" "$MONOREPO_EXPR" 2>&1
}

echo "TEST: with no selection, triage is uploaded and nothing changes"
out="$(run_prepare)"
check "monorepo expression uploaded" "1" "$(echo "$out" | grep -c "UPLOADED: ${MONOREPO_EXPR}")"
check "RunSelection is not uploaded" "0" "$(echo "$out" | grep -c 'RunSelection')"

echo "TEST: a step selection switches to RunSelection"
out="$(run_prepare BUILDKITE_PIPELINE_SELECTION='daemon_config-*')"
check "RunSelection uploaded" "1" "$(echo "$out" | grep -c 'UPLOADED: (./buildkite/src/Entrypoints/RunSelection.dhall)')"
check "triage is not uploaded" "0" "$(echo "$out" | grep -c 'Monorepo.dhall')"
check "the chosen steps are written out" "1" "$(echo "$out" | grep -c 'steps:    daemon_config-\*')"

echo "TEST: a package selection alone also switches"
out="$(run_prepare BUILDKITE_PIPELINE_DEB_SELECTION='prefork_*')"
check "RunSelection uploaded" "1" "$(echo "$out" | grep -c 'RunSelection.dhall')"
check "the chosen packages are written out" "1" "$(echo "$out" | grep -c 'packages: prefork_\*')"

echo "TEST: an empty selection is the same as none at all"
out="$(run_prepare BUILDKITE_PIPELINE_SELECTION='' BUILDKITE_PIPELINE_DEB_SELECTION='')"
check "monorepo expression uploaded" "1" "$(echo "$out" | grep -c 'Monorepo.dhall')"

echo "TEST: the value is never put into the uploaded expression"
# A value that tries to close the quote and read the environment must end up in
# no expression at all. RunSelection.dhall takes no argument, so there is
# nowhere for it to go.
out="$(run_prepare BUILDKITE_PIPELINE_SELECTION="x' ++ env:BUILDKITE_AGENT_ACCESS_TOKEN as Text ++ '")"
check "the uploaded expression is the plain entrypoint" "1" \
    "$(echo "$out" | grep -c '^UPLOADED: (./buildkite/src/Entrypoints/RunSelection.dhall)$')"
check "no environment read reaches the expression" "0" \
    "$(echo "$out" | grep '^UPLOADED:' | grep -c 'env:')"

echo "TEST: without the triage expression the script stops"
status=0
env -u BUILDKITE_PIPELINE_SELECTION -u BUILDKITE_PIPELINE_DEB_SELECTION \
    "${SANDBOX}/prepare_upload.sh" > /dev/null 2>&1 || status=$?
check "exit code" "2" "$status"

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

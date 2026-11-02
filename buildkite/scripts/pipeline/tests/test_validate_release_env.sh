#!/bin/bash
set -euo pipefail

# Tests for validate-release-env.sh
#
# Usage: bash buildkite/scripts/pipeline/tests/test_validate_release_env.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="${SCRIPT_DIR}/../validate-release-env.sh"

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

# run <label> <expected exit code> [VAR=value ...]
run() {
    local label="$1" expected="$2" status=0
    shift 2
    env -u MINA_RELEASE_DOCKER_REPO -u MINA_RELEASE_DEBIAN_REPOS "$@" "$VALIDATE" > /dev/null 2>&1 || status=$?
    check "$label" "$expected" "$status"
}

# message <VAR=value ...>: what the script says on stderr
message() {
    # shellcheck disable=SC2069 # stderr is wanted, stdout is not
    env -u MINA_RELEASE_DOCKER_REPO -u MINA_RELEASE_DEBIAN_REPOS "$@" "$VALIDATE" 2>&1 >/dev/null || true
}

D='< Internal | InternalEurope | Public >'
R='< Unstable | Nightly | Stable | O1Test >'

echo "TEST: unset is a real answer"
run "both unset" 0

echo "TEST: MINA_RELEASE_DOCKER_REPO"
run "Public" 0 "MINA_RELEASE_DOCKER_REPO=${D}.Public"
run "InternalEurope" 0 "MINA_RELEASE_DOCKER_REPO=${D}.InternalEurope"
run "typo in the alternative" 1 "MINA_RELEASE_DOCKER_REPO=${D}.Pubic"
run "plain word" 1 "MINA_RELEASE_DOCKER_REPO=Public"
run "an address" 1 "MINA_RELEASE_DOCKER_REPO=docker.io/minaprotocol"
run "another union" 1 "MINA_RELEASE_DOCKER_REPO=< Foo | Bar >.Foo"

echo "TEST: MINA_RELEASE_DEBIAN_REPOS"
run "one repository" 0 "MINA_RELEASE_DEBIAN_REPOS=[ ${R}.O1Test ]"
run "two repositories" 0 "MINA_RELEASE_DEBIAN_REPOS=[ ${R}.O1Test, ${R}.Stable ]"
run "no spaces around the brackets" 0 "MINA_RELEASE_DEBIAN_REPOS=[${R}.Stable]"
run "a newline inside the list" 0 "MINA_RELEASE_DEBIAN_REPOS=[ ${R}.O1Test,
${R}.Stable ]"
run "not a list" 1 "MINA_RELEASE_DEBIAN_REPOS=${R}.O1Test"
run "plain word" 1 "MINA_RELEASE_DEBIAN_REPOS=[ O1Test ]"
run "typo in one element" 1 "MINA_RELEASE_DEBIAN_REPOS=[ ${R}.O1Test, ${R}.Stabel ]"
run "empty list" 1 "MINA_RELEASE_DEBIAN_REPOS=[]"
run "empty list with spaces" 1 "MINA_RELEASE_DEBIAN_REPOS=[ ]"
run "a repository twice" 1 "MINA_RELEASE_DEBIAN_REPOS=[ ${R}.Stable, ${R}.Stable ]"
run "wrong alternative set" 1 "MINA_RELEASE_DEBIAN_REPOS=[ ${D}.Public ]"

echo "TEST: both are checked, and a good one does not excuse a bad one"
run "good docker, bad debian" 1 "MINA_RELEASE_DOCKER_REPO=${D}.Public" "MINA_RELEASE_DEBIAN_REPOS=[ O1Test ]"
run "bad docker, good debian" 1 "MINA_RELEASE_DOCKER_REPO=Public" "MINA_RELEASE_DEBIAN_REPOS=[ ${R}.O1Test ]"
run "both good" 0 "MINA_RELEASE_DOCKER_REPO=${D}.Public" "MINA_RELEASE_DEBIAN_REPOS=[ ${R}.O1Test, ${R}.Stable ]"

echo "TEST: the message names the variable and the element"
msg="$(message "MINA_RELEASE_DEBIAN_REPOS=[ ${R}.O1Test, ${R}.Stabel ]")"
check "names the variable" "1" "$(grep -c 'MINA_RELEASE_DEBIAN_REPOS is set' <<< "$msg")"
check "names the element" "1" "$(grep -c "element '${R}.Stabel' is not" <<< "$msg")"
msg="$(message "MINA_RELEASE_DEBIAN_REPOS=[ ${R}.Stable, ${R}.Stable ]")"
check "says it is listed twice" "1" "$(grep -c 'listed twice' <<< "$msg")"

echo ""
echo "${PASSED}/${RUN} passed"
if [[ $FAILED -gt 0 ]]; then
    printf '  - %s\n' "${FAILURES[@]}"
    exit 1
fi

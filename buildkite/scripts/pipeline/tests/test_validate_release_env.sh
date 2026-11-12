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

CLEAN=(env -u MINA_RELEASE_DOCKER_REPO -u MINA_RELEASE_DOCKER_MIRROR -u MINA_RELEASE_DEBIAN_REPO -u MINA_RELEASE_DEBIAN_MIRROR)

# run <label> <expected exit code> [VAR=value ...]
run() {
    local label="$1" expected="$2" status=0
    shift 2
    "${CLEAN[@]}" "$@" "$VALIDATE" > /dev/null 2>&1 || status=$?
    check "$label" "$expected" "$status"
}

# message <VAR=value ...>: what the script says on stderr
message() {
    # shellcheck disable=SC2069 # stderr is wanted, stdout is not
    "${CLEAN[@]}" "$@" "$VALIDATE" 2>&1 >/dev/null || true
}

D='< Internal | InternalEurope | Public >'
R='< Unstable | Nightly | Stable | O1Test >'

echo "TEST: unset is a real answer"
run "all unset" 0

echo "TEST: MINA_RELEASE_DOCKER_REPO"
run "Public" 0 "MINA_RELEASE_DOCKER_REPO=${D}.Public"
run "InternalEurope" 0 "MINA_RELEASE_DOCKER_REPO=${D}.InternalEurope"
run "typo in the alternative" 1 "MINA_RELEASE_DOCKER_REPO=${D}.Pubic"
run "plain word" 1 "MINA_RELEASE_DOCKER_REPO=Public"
run "an address" 1 "MINA_RELEASE_DOCKER_REPO=docker.io/minaprotocol"
run "another union" 1 "MINA_RELEASE_DOCKER_REPO=< Foo | Bar >.Foo"

echo "TEST: MINA_RELEASE_DOCKER_MIRROR"
run "mirror alone" 0 "MINA_RELEASE_DOCKER_MIRROR=${D}.Public"
run "repo and mirror" 0 "MINA_RELEASE_DOCKER_REPO=${D}.Public" "MINA_RELEASE_DOCKER_MIRROR=${D}.InternalEurope"
run "typo in the mirror" 1 "MINA_RELEASE_DOCKER_MIRROR=${D}.InternalEurop"
run "the debian union" 1 "MINA_RELEASE_DOCKER_MIRROR=${R}.Stable"
run "mirror equal to the repo" 1 "MINA_RELEASE_DOCKER_REPO=${D}.Public" "MINA_RELEASE_DOCKER_MIRROR=${D}.Public"
run "mirror equal to the packaging default" 1 "MINA_RELEASE_DOCKER_MIRROR=${D}.InternalEurope"
run "mirror InternalEurope with another repo" 0 "MINA_RELEASE_DOCKER_REPO=${D}.Public" "MINA_RELEASE_DOCKER_MIRROR=${D}.InternalEurope"

echo "TEST: MINA_RELEASE_DEBIAN_REPO"
run "Stable" 0 "MINA_RELEASE_DEBIAN_REPO=${R}.Stable"
run "O1Test" 0 "MINA_RELEASE_DEBIAN_REPO=${R}.O1Test"
run "typo in the alternative" 1 "MINA_RELEASE_DEBIAN_REPO=${R}.Stabel"
run "plain word" 1 "MINA_RELEASE_DEBIAN_REPO=Stable"
run "a list" 1 "MINA_RELEASE_DEBIAN_REPO=[ ${R}.Stable ]"
run "the docker union" 1 "MINA_RELEASE_DEBIAN_REPO=${D}.Public"

echo "TEST: MINA_RELEASE_DEBIAN_MIRROR"
run "mirror alone" 0 "MINA_RELEASE_DEBIAN_MIRROR=${R}.Stable"
run "repo and mirror" 0 "MINA_RELEASE_DEBIAN_REPO=${R}.O1Test" "MINA_RELEASE_DEBIAN_MIRROR=${R}.Stable"
run "typo in the mirror" 1 "MINA_RELEASE_DEBIAN_MIRROR=${R}.Stabel"
run "mirror equal to the repo" 1 "MINA_RELEASE_DEBIAN_REPO=${R}.Stable" "MINA_RELEASE_DEBIAN_MIRROR=${R}.Stable"
run "mirror equal to the job default" 1 "MINA_RELEASE_DEBIAN_MIRROR=${R}.O1Test"
run "mirror O1Test with another repo" 0 "MINA_RELEASE_DEBIAN_REPO=${R}.Stable" "MINA_RELEASE_DEBIAN_MIRROR=${R}.O1Test"

echo "TEST: every variable is checked, and a good one does not excuse a bad one"
run "good docker, bad debian" 1 "MINA_RELEASE_DOCKER_REPO=${D}.Public" "MINA_RELEASE_DEBIAN_REPO=O1Test"
run "bad docker, good debian" 1 "MINA_RELEASE_DOCKER_REPO=Public" "MINA_RELEASE_DEBIAN_REPO=${R}.O1Test"
run "all good" 0 "MINA_RELEASE_DOCKER_REPO=${D}.Public" "MINA_RELEASE_DOCKER_MIRROR=${D}.InternalEurope" "MINA_RELEASE_DEBIAN_REPO=${R}.O1Test" "MINA_RELEASE_DEBIAN_MIRROR=${R}.Stable"

echo "TEST: the message names the variable and the problem"
msg="$(message "MINA_RELEASE_DEBIAN_MIRROR=${R}.Stabel")"
check "names the variable" "1" "$(grep -c 'MINA_RELEASE_DEBIAN_MIRROR is set' <<< "$msg")"
check "lists the accepted spellings" "1" "$(grep -c "${R}.Stable\$" <<< "$msg")"
msg="$(message "MINA_RELEASE_DEBIAN_MIRROR=${R}.O1Test")"
check "says the mirror is the primary" "1" "$(grep -c 'already goes to' <<< "$msg")"
check "says the primary is the job default" "1" "$(grep -c 'the job default' <<< "$msg")"
msg="$(message "MINA_RELEASE_DOCKER_MIRROR=${D}.InternalEurope")"
check "names the docker mirror" "1" "$(grep -c 'MINA_RELEASE_DOCKER_MIRROR names' <<< "$msg")"

echo ""
echo "${PASSED}/${RUN} passed"
if [[ $FAILED -gt 0 ]]; then
    printf '  - %s\n' "${FAILURES[@]}"
    exit 1
fi

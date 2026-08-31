#!/bin/bash
set -uo pipefail

# Tests for apps/write_portable_to_cache.sh and apps/restore_portable.sh
#
# Usage: bash buildkite/scripts/tests/test_portable_cache.sh
#
# Drives the REAL cache manager against a throwaway CACHE_BASE_URL, the same way
# cache/tests/cache-parity-test.sh does, so this exercises the actual cache
# layout rather than a stub that could agree with a wrong assumption.
#
# The bundle here is synthetic -- a fake loader that echoes its arguments --
# because what these two scripts are responsible for is the round trip: that a
# tree written on one agent comes back intact and runnable on another. Whether
# the bundle's CONTENTS are correct is bundle-libs.sh's job and is covered by
# test_bundle_libs.sh.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT" || exit 1

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

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A throwaway cache. Both scripts require Buildkite context, so supply it.
export CACHE_BASE_URL="${WORK}/cache"
export BUILDKITE_BUILD_ID="test-build-id"
mkdir -p "$CACHE_BASE_URL"

# Build a synthetic bundle at $1 with the layout build-artifact.sh produces.
make_bundle() {
    local root="$1" with_loader="${2:-yes}"
    mkdir -p "${root}/bin" "${root}/libexec" "${root}/lib"
    echo "not a real elf" > "${root}/libexec/mina.exe"
    echo "libc" > "${root}/lib/libc.so.6"
    if [[ "$with_loader" == "yes" ]]; then
        cat > "${root}/lib/ld-linux-x86-64.so.2" <<'LOADER'
#!/bin/sh
echo "ran exe=$3 args=$4"
LOADER
        chmod 0755 "${root}/lib/ld-linux-x86-64.so.2"
        # shellcheck source=buildkite/scripts/bundle-libs.sh
        source ./buildkite/scripts/bundle-libs.sh
        bundle_write_wrapper "${root}/bin/mina" lib "libexec/mina.exe" \
            "ld-linux-x86-64.so.2"
    fi
    printf '# portable bundle closure\nmina.exe\tlibc.so.6\n' \
        > "${root}/closure-report.txt"
}

echo "TEST: a build with no bundle publishes nothing and does not fail"
export MINA_PORTABLE_ROOT="${WORK}/absent"
status=0
./buildkite/scripts/apps/write_portable_to_cache.sh noble >/dev/null 2>&1 || status=$?
check "exit status" "0" "$status"
check "nothing written to the cache" "0" \
    "$(find "$CACHE_BASE_URL" -name 'mina-portable.tar.gz' 2>/dev/null | wc -l)"

echo "TEST: a bundle round-trips through the cache and still runs"
export MINA_PORTABLE_ROOT="${WORK}/src/_build_portable"
make_bundle "$MINA_PORTABLE_ROOT"
status=0
./buildkite/scripts/apps/write_portable_to_cache.sh noble >/dev/null 2>&1 || status=$?
check "write exit status" "0" "$status"
check "tarball is in the cache" "1" \
    "$(find "$CACHE_BASE_URL" -name 'mina-portable.tar.gz' | wc -l)"
check "the closure report is beside it, unpacked" "1" \
    "$(find "$CACHE_BASE_URL" -name 'closure-report.txt' | wc -l)"

# Restore on a "different agent": a fresh directory with no bundle in it.
dest="${WORK}/consumer"
mkdir -p "$dest"
export MINA_PORTABLE_ROOT="${dest}/_build_portable"
status=0
./buildkite/scripts/apps/restore_portable.sh noble >/dev/null 2>&1 || status=$?
check "restore exit status" "0" "$status"
check "the wrapper came back" "1" \
    "$([[ -x "${dest}/_build_portable/bin/mina" ]] && echo 1 || echo 0)"
check "the loader came back" "1" \
    "$([[ -f "${dest}/_build_portable/lib/ld-linux-x86-64.so.2" ]] && echo 1 || echo 0)"
check "the real binary came back" "1" \
    "$([[ -f "${dest}/_build_portable/libexec/mina.exe" ]] && echo 1 || echo 0)"

out="$(cd / && "${dest}/_build_portable/bin/mina" --version 2>&1)"
check "the restored wrapper runs the restored binary" "1" \
    "$(echo "$out" | grep -c "exe=${dest}/_build_portable/libexec/mina.exe")"
check "and forwards arguments" "1" "$(echo "$out" | grep -c 'args=--version')"

echo "TEST: variants do not collide"
export MINA_PORTABLE_ROOT="${WORK}/src/_build_portable"
./buildkite/scripts/apps/write_portable_to_cache.sh noble arm64 >/dev/null 2>&1
check "the variant has its own directory" "1" \
    "$(find "$CACHE_BASE_URL" -path '*noble/arm64/mina-portable.tar.gz' | wc -l)"
check "the default is still its own" "1" \
    "$(find "$CACHE_BASE_URL" -path '*noble/mina-portable.tar.gz' | wc -l)"

echo "TEST: a consumer fails hard when the bundle is absent"
export MINA_PORTABLE_ROOT="${WORK}/consumer2/_build_portable"
mkdir -p "${WORK}/consumer2"
status=0
msg="$(./buildkite/scripts/apps/restore_portable.sh bookworm 2>&1)" || status=$?
check "exit status is non-zero" "1" "$([[ "$status" -ne 0 ]] && echo 1 || echo 0)"
check "it says what must run first" "1" \
    "$(echo "$msg" | grep -c 'MINA_BUILD_PORTABLE=1')"
check "it did not leave a partial tree" "0" \
    "$([[ -d "$MINA_PORTABLE_ROOT" ]] && echo 1 || echo 0)"

echo "TEST: a bundle with no loader is rejected rather than restored"
export MINA_PORTABLE_ROOT="${WORK}/broken/_build_portable"
make_bundle "$MINA_PORTABLE_ROOT" no
./buildkite/scripts/apps/write_portable_to_cache.sh focal >/dev/null 2>&1
export MINA_PORTABLE_ROOT="${WORK}/consumer3/_build_portable"
mkdir -p "${WORK}/consumer3"
status=0
msg="$(./buildkite/scripts/apps/restore_portable.sh focal 2>&1)" || status=$?
check "exit status is non-zero" "1" "$([[ "$status" -ne 0 ]] && echo 1 || echo 0)"
check "it names the missing loader" "1" "$(echo "$msg" | grep -c 'no dynamic loader')"

echo
echo "Ran ${RUN}, passed ${PASSED}, failed ${FAILED}"
if [[ "$FAILED" -gt 0 ]]; then
    printf '%s\n' "${FAILURES[@]}" >&2
    exit 1
fi

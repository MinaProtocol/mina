#!/bin/bash
set -euo pipefail

# Tests for bundle-libs.sh
#
# Usage: bash buildkite/scripts/tests/test_bundle_libs.sh
#
# The collection rules are tested against a stub `ldd` rather than real
# binaries, because the cases that matter are the ones a build agent will not
# reproduce on demand: a library the image lacks, a bundle with no loader, an
# NSS module ldd never mentions. The stub makes each of those a fixture.
#
# One end-to-end test compiles a real binary and runs it through a real
# wrapper. It is skipped, not failed, where there is no compiler.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=buildkite/scripts/bundle-libs.sh
source "${SCRIPT_DIR}/../bundle-libs.sh"

RUN=0; PASSED=0; FAILED=0; SKIPPED=0; FAILURES=()

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

skip() {
    SKIPPED=$((SKIPPED + 1))
    echo "  SKIP $1" >&2
}

# How many files in $1 match glob $2. A glob rather than `ls | grep`: the
# linter rejects that form, and it would misread a name containing a newline.
count() {
    local dir="$1" pattern="$2" n=0 f
    # shellcheck disable=SC2231  # an unquoted glob is the point here
    for f in "$dir"/$pattern; do
        [[ -e "$f" ]] && n=$((n + 1))
    done
    echo "$n"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A stub ldd that prints the fixture named by the binary it is asked about, so a
# test can describe any dependency situation it likes. It shadows the real ldd
# through PATH, and `command -v ldd` still finds it.
STUB_BIN="${WORK}/stub-bin"
mkdir -p "$STUB_BIN"
cat > "${STUB_BIN}/ldd" <<'STUB'
#!/bin/bash
fixture="$(dirname "$1")/$(basename "$1").ldd"
[[ -f "$fixture" ]] && cat "$fixture"
exit 0
STUB
chmod 0755 "${STUB_BIN}/ldd"

# A fake sysroot: bundle_collect only copies paths that exist, so the fixtures
# have to point at real files.
SYSROOT="${WORK}/sysroot"
mkdir -p "${SYSROOT}/lib"
for lib in libc.so.6 libm.so.6 libgmp.so.10 ld-linux-x86-64.so.2 \
           libnss_files.so.2 libnss_dns.so.2; do
    echo "$lib" > "${SYSROOT}/lib/${lib}"
done

# Build an exe fixture: a file standing in for the binary, plus the ldd output
# it should produce.
make_exe() {
    local name="$1" dir="${WORK}/exes"
    mkdir -p "$dir"
    echo "$name" > "${dir}/${name}"
    cat > "${dir}/${name}.ldd"
    echo "${dir}/${name}"
}

resolved() { printf '\tlib => %s (0x00007f0000000000)\n' "$1"; }

echo "TEST: the resolved closure, the loader and the dlopened NSS modules"
exe="$(make_exe app1 <<FIXTURE
	linux-vdso.so.1 (0x00007ffd00000000)
$(resolved "${SYSROOT}/lib/libm.so.6")
$(resolved "${SYSROOT}/lib/libc.so.6")
	${SYSROOT}/lib/ld-linux-x86-64.so.2 (0x00007f1111111000)
FIXTURE
)"
libdir="${WORK}/out1"
PATH="${STUB_BIN}:${PATH}" bundle_collect "$exe" "$libdir"
check "ldd-resolved libs are copied" "1" "$(count "$libdir" 'libm.so.6')"
check "glibc is bundled, not left to the host" "1" "$(count "$libdir" 'libc.so.6')"
check "the loader is bundled" "1" "$(count "$libdir" 'ld-linux-x86-64.so.2')"
check "NSS modules ldd never mentions" "2" "$(count "$libdir" 'libnss_*')"
check "linux-vdso is not a file to copy" "0" "$(count "$libdir" '*vdso*')"

echo "TEST: a shared libdir deduplicates across binaries"
exe2="$(make_exe app2 <<FIXTURE
$(resolved "${SYSROOT}/lib/libc.so.6")
$(resolved "${SYSROOT}/lib/libgmp.so.10")
FIXTURE
)"
before="$(cat "${libdir}/libc.so.6")"
echo "MUTATED" > "${SYSROOT}/lib/libc.so.6"
PATH="${STUB_BIN}:${PATH}" bundle_collect "$exe2" "$libdir"
check "the second binary's own libs arrive" "1" "$(count "$libdir" 'libgmp.so.10')"
check "an already-bundled lib is not re-copied" "$before" "$(cat "${libdir}/libc.so.6")"
echo "libc.so.6" > "${SYSROOT}/lib/libc.so.6"

echo "TEST: a library the build image lacks is reported, not silently dropped"
exe3="$(make_exe app3 <<FIXTURE
	libpcre2-8.so.0 => not found
$(resolved "${SYSROOT}/lib/libc.so.6")
	libz.so.1 => not found
FIXTURE
)"
missing="$(PATH="${STUB_BIN}:${PATH}" bundle_missing "$exe3")"
check "both unresolved libs are named" "libpcre2-8.so.0 libz.so.1" "$(echo "$missing" | tr '\n' ' ' | sed 's/ $//')"
libdir3="${WORK}/out3"
PATH="${STUB_BIN}:${PATH}" bundle_collect "$exe3" "$libdir3"
check "an unresolved lib cannot be bundled" "0" "$(count "$libdir3" '*pcre2*')"

echo "TEST: nothing missing means nothing reported"
check "a complete closure reports empty" "" "$(PATH="${STUB_BIN}:${PATH}" bundle_missing "$exe")"

echo "TEST: the loader lookup"
check "finds the loader in a bundle" "ld-linux-x86-64.so.2" "$(bundle_loader_name "$libdir")"
mkdir -p "${WORK}/noloader"
echo "libc" > "${WORK}/noloader/libc.so.6"
check "a bundle without one yields nothing" "" "$(bundle_loader_name "${WORK}/noloader")"
check "and that is not an error" "0" "$(bundle_loader_name "${WORK}/noloader" >/dev/null; echo $?)"

echo "TEST: the loader lookup survives a large bundle under set -eo pipefail"
# This is a contract test -- big bundle in, loader out, exit 0 -- rather than a
# reproduction of one broken implementation. A `find | head -1` only takes
# SIGPIPE when find itself writes past the pipe buffer, so whether any given
# rewrite trips depends on its exact shape; what must hold regardless is that
# the size of a bundle never changes the answer.
#
# The bundle has to be big enough for that to happen: head exits after the first
# line, and find only takes the signal once it writes past the ~64KB pipe
# buffer. A few hundred short names stay inside the buffer and the bug hides, so
# the filler names are long and there are enough of them to clear it several
# times over.
big="${WORK}/bigbundle"
mkdir -p "$big"
filler="libfiller-with-a-deliberately-long-name-to-fill-the-pipe-buffer"
for i in $(seq 1 3000); do : > "${big}/${filler}-${i}.so.1"; done
echo loader > "${big}/ld-linux-x86-64.so.2"
check "the fixture clears the pipe buffer" "1" \
    "$([[ "$(find "$big" -maxdepth 1 | wc -c)" -gt 65536 ]] && echo 1 || echo 0)"
status=0
out="$(set -eo pipefail; bundle_loader_name "$big")" || status=$?
check "exit status" "0" "$status"
check "still finds the loader" "ld-linux-x86-64.so.2" "$out"

echo "TEST: the generated wrapper runs the BUNDLED loader, relocatably"
# A fake loader that reports how it was invoked, so this holds without a real
# ELF: what matters is that the wrapper execs the loader from its own tree,
# passes --library-path, and forwards its arguments.
tree="${WORK}/tree"
mkdir -p "${tree}/bin" "${tree}/lib" "${tree}/libexec"
cat > "${tree}/lib/ld-linux-x86-64.so.2" <<'LOADER'
#!/bin/sh
echo "loader=$0 libpath=$2 exe=$3 args=$4"
LOADER
chmod 0755 "${tree}/lib/ld-linux-x86-64.so.2"
echo "real elf" > "${tree}/libexec/mina.exe"
bundle_write_wrapper "${tree}/bin/mina" lib "libexec/mina.exe" "ld-linux-x86-64.so.2"

out="$("${tree}/bin/mina" --help)"
check "execs the loader from its own tree" "1" "$(echo "$out" | grep -c "loader=${tree}/lib/ld-linux-x86-64.so.2")"
check "passes --library-path at the bundle" "1" "$(echo "$out" | grep -c "libpath=${tree}/lib")"
check "runs the binary out of libexec" "1" "$(echo "$out" | grep -c "exe=${tree}/libexec/mina.exe")"
check "forwards arguments" "1" "$(echo "$out" | grep -c 'args=--help')"

moved="${WORK}/moved-tree"
mv "$tree" "$moved"
out="$(cd / && "${moved}/bin/mina" --version)"
check "the moved tree uses its new location" "1" "$(echo "$out" | grep -c "loader=${moved}/lib/ld-linux-x86-64.so.2")"
check "and not the old one" "0" "$(echo "$out" | grep -c "$tree")"

out="$(cd / && PATH="${moved}/bin:${PATH}" mina --version)"
check "works when invoked through PATH" "1" "$(echo "$out" | grep -c "exe=${moved}/libexec/mina.exe")"

echo "TEST: end to end, a real binary under a real bundled loader"
if ! command -v gcc >/dev/null 2>&1; then
    skip "no gcc available to build a real binary"
else
    real="${WORK}/real"
    mkdir -p "${real}/bin" "${real}/lib" "${real}/libexec"
    cat > "${WORK}/probe.c" <<'PROBE'
#include <stdio.h>
#include <netdb.h>
int main(int argc, char **argv) {
    struct hostent *h = gethostbyname("localhost");
    printf("argv1=%s nss=%s\n", argc > 1 ? argv[1] : "none",
           h ? h->h_name : "NULL");
    return 0;
}
PROBE
    gcc "${WORK}/probe.c" -o "${real}/libexec/probe.exe"

    check "the probe's closure is complete" "" "$(bundle_missing "${real}/libexec/probe.exe")"
    bundle_collect "${real}/libexec/probe.exe" "${real}/lib"
    loader="$(bundle_loader_name "${real}/lib")"
    check "a real closure carries a loader" "1" "$([[ -n "$loader" ]] && echo 1 || echo 0)"
    check "a real closure carries glibc" "1" "$(count "${real}/lib" 'libc.so*')"
    check "a real closure carries NSS modules" "1" \
        "$([[ "$(count "${real}/lib" 'libnss_*')" -gt 0 ]] && echo 1 || echo 0)"

    bundle_write_wrapper "${real}/bin/probe" lib "libexec/probe.exe" "$loader"
    relocated="${WORK}/real-moved"
    mv "$real" "$relocated"
    out="$(cd / && "${relocated}/bin/probe" hello 2>&1)"
    check "the relocated binary runs" "1" "$(echo "$out" | grep -c 'argv1=hello')"
    # A bundled glibc that cannot find its NSS modules fails exactly here.
    check "name lookups work under the bundled glibc" "1" "$(echo "$out" | grep -c 'nss=localhost')"
fi

echo
echo "Ran ${RUN}, passed ${PASSED}, failed ${FAILED}, skipped ${SKIPPED}"
if [[ "$FAILED" -gt 0 ]]; then
    printf '%s\n' "${FAILURES[@]}" >&2
    exit 1
fi

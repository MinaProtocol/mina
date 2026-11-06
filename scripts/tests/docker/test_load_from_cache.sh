#!/usr/bin/env bash

# Tests for buildkite/scripts/docker/load_from_cache.sh, against stub docker
# and zstd. An archive is a text file; the stub "loads" whatever it reads.
# STUB_LOCAL lists the refs the stub daemon already holds.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="${REPO_ROOT}/buildkite/scripts/docker/load_from_cache.sh"

PASSED=0
FAILED=0
pass () { PASSED=$((PASSED + 1)); }
fail () { echo "  FAIL: $*"; FAILED=$((FAILED + 1)); }
expect () {
  local message="$1"
  shift
  if "$@"; then pass; else fail "$message"; fi
}
not () { ! "$@"; }

WORK=""
setup () {
  WORK="$(mktemp -d)"
  mkdir -p "${WORK}/bin" "${WORK}/cache/mina-daemon"
  cat > "${WORK}/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "${CALLS}"
case "$1 $2" in
  "image inspect")
    for ref in ${STUB_LOCAL:-}; do [[ "$ref" == "${!#}" ]] && exit 0; done
    exit 1 ;;
  "load "*|"load")
    while read -r tag; do echo "Loaded image: $tag"; done ;;
esac
exit 0
STUB
  cat > "${WORK}/bin/zstd" <<'STUB'
#!/usr/bin/env bash
cat "$2"
STUB
  chmod +x "${WORK}/bin/docker" "${WORK}/bin/zstd"
  echo "reg/mina-daemon:1.0.0-devnet" > "${WORK}/cache/mina-daemon/1.0.0-devnet.tar.zst"
  mkdir -p "${WORK}/cache/mina-toolchain"
  echo "reg/mina-toolchain:abc-bookworm" > "${WORK}/cache/mina-toolchain/abc-bookworm.tar.zst"
}
teardown () { rm -rf "$WORK"; }

# run <image> [VAR=value...]: exit code in RC, output in OUT, docker calls in CALLS.
run () {
  local image="$1"
  shift
  export CALLS="${WORK}/calls"
  : > "$CALLS"
  set +e
  OUT="$(env PATH="${WORK}/bin:${PATH}" CACHE_ROOT="${WORK}/cache" DISK_CLEANUP=0 \
    "$@" "$SCRIPT" "$image" 2>&1)"
  RC=$?
  set -e
}

called () { grep -qx -- "$1" "$CALLS"; }
owned () { [[ -f "${WORK}/owned" ]] && grep -qx -- "$1" "${WORK}/owned"; }

t_records_what_it_loaded () {
  run reg/mina-daemon:1.0.0-devnet OWNED_REFS_FILE="${WORK}/owned"
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "must load" called "load"
  expect "the loaded ref is owned" owned "reg/mina-daemon:1.0.0-devnet"
}

t_does_not_own_an_image_that_was_already_local () {
  run reg/mina-daemon:1.0.0-devnet OWNED_REFS_FILE="${WORK}/owned" STUB_LOCAL="reg/mina-daemon:1.0.0-devnet"
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "a local image is not loaded again" not called "load"
  expect "a local image belongs to whoever loaded it" not owned "reg/mina-daemon:1.0.0-devnet"
}

t_never_owns_the_toolchain () {
  run reg/mina-toolchain:abc-bookworm OWNED_REFS_FILE="${WORK}/owned"
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "must load" called "load"
  expect "the toolchain stays for the next job" test ! -e "${WORK}/owned"
}

t_unset_refs_file_records_nothing () {
  run reg/mina-daemon:1.0.0-devnet OWNED_REFS_FILE=
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "must load" called "load"
  expect "no refs file is written" test ! -e "${WORK}/owned"
}

t_missing_archive_fails () {
  run reg/mina-daemon:nope OWNED_REFS_FILE="${WORK}/owned"
  expect "a cache miss must fail" test $RC -ne 0
  expect "nothing is owned on a miss" test ! -e "${WORK}/owned"
}

for t in $(declare -F | awk '$3 ~ /^t_/ {print $3}'); do
  setup
  echo "$t"
  "$t"
  teardown
done

echo "passed ${PASSED}, failed ${FAILED}"
[[ "$FAILED" -eq 0 ]]

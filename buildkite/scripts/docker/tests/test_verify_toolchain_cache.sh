#!/usr/bin/env bash

# Tests for buildkite/scripts/docker/verify-toolchain-cache.sh, against stub
# docker and zstd. The stub gives a pulled ref the ID "sha256:<ref>"; an
# archive is a text file whose first line is what `docker load` reports.
# STUB_CACHED_IDS maps "<tag>=<id>" for a loaded archive whose content differs
# from docker.io; otherwise the load reports the same ref and so the same ID.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SCRIPT="${REPO_ROOT}/buildkite/scripts/docker/verify-toolchain-cache.sh"

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
  mkdir -p "${WORK}/bin" "${WORK}/cache/mina-toolchain"
  cat > "${WORK}/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "${CALLS}"
case "$1 $2" in
  "pull --quiet") exit 0 ;;
  "image inspect")
    ref="${!#}"
    [[ "$ref" == sha256:* ]] && { echo "$ref"; exit 0; }
    echo "sha256:${ref}" ;;
  "load "*|"load") read -r line; echo "$line" ;;
  "save "*) echo "saved ${3:-}" ;;
esac
exit 0
STUB
  cat > "${WORK}/bin/zstd" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "-dc" ]]; then cat "$2"; else cat; fi
STUB
  chmod +x "${WORK}/bin/docker" "${WORK}/bin/zstd"
}
teardown () { rm -rf "$WORK"; }

# archive <tag> [<loaded line>]: a cached mina-toolchain:<tag>.
archive () {
  local tag="$1" line="${2:-Loaded image: docker.io/minaprotocol/mina-toolchain:$1}"
  echo "$line" > "${WORK}/cache/mina-toolchain/${tag}.tar.zst"
}

# run [VAR=value...]: exit code in RC, output in OUT, docker calls in CALLS.
run () {
  export CALLS="${WORK}/calls"
  : > "$CALLS"
  set +e
  OUT="$(env PATH="${WORK}/bin:${PATH}" CACHE_ROOT="${WORK}/cache" "$@" "$SCRIPT" 2>&1)"
  RC=$?
  set -e
}

called () { grep -qx -- "$1" "$CALLS"; }
line_of () { grep -n -m1 -x -- "$1" "$CALLS" | cut -d: -f1; }

t_drops_each_image_before_pulling_the_next () {
  archive a
  archive b
  run
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "a is validated" grep -q "^OK a" <<< "$OUT"
  expect "the tag of a is dropped" called "image rm docker.io/minaprotocol/mina-toolchain:a"
  expect "the image of a is dropped by ID" called "image rm sha256:docker.io/minaprotocol/mina-toolchain:a"
  expect "a is dropped before b is pulled" \
    test "$(line_of "image rm docker.io/minaprotocol/mina-toolchain:a")" -lt \
         "$(line_of "pull --quiet docker.io/minaprotocol/mina-toolchain:b")"
  expect "b is dropped too" called "image rm docker.io/minaprotocol/mina-toolchain:b"
}

t_replaces_a_mismatch_then_drops_both_images () {
  archive a "Loaded image ID: sha256:stale"
  run
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "the cache entry is replaced" grep -q "^REPLACED" <<< "$OUT"
  expect "the docker.io copy is saved" called "save sha256:docker.io/minaprotocol/mina-toolchain:a"
  expect "the docker.io image is dropped" called "image rm sha256:docker.io/minaprotocol/mina-toolchain:a"
  expect "the stale cached image is dropped" called "image rm sha256:stale"
  expect "the drop comes after the save" \
    test "$(line_of "image rm sha256:stale")" -gt "$(line_of "save sha256:docker.io/minaprotocol/mina-toolchain:a")"
}

t_records_pulls_for_the_exit_trap () {
  archive a
  run OWNED_REFS_FILE="${WORK}/owned"
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "the pulled ref is owned" grep -qx "docker.io/minaprotocol/mina-toolchain:a" "${WORK}/owned"
}

for t in $(declare -F | awk '$3 ~ /^t_/ {print $3}'); do
  setup
  echo "$t"
  "$t"
  teardown
done

echo "passed ${PASSED}, failed ${FAILED}"
[[ "$FAILED" -eq 0 ]]

#!/usr/bin/env bash

# Tests for buildkite/scripts/docker/publish_from_cache.sh, against stub docker
# and zstd. An archive is a text file with one tag on each line; the stub
# "loads" it by printing those tags, and gives each image the ID "sha256:<tag>".

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SCRIPT="${REPO_ROOT}/buildkite/scripts/docker/publish_from_cache.sh"

PASSED=0
FAILED=0
pass () { PASSED=$((PASSED + 1)); }
fail () { echo "  FAIL: $*"; FAILED=$((FAILED + 1)); }
# expect <message> <command...>: pass when the command succeeds.
expect () {
  local message="$1"
  shift
  if "$@"; then pass; else fail "$message"; fi
}
not () { ! "$@"; }

WORK=""
setup () {
  WORK="$(mktemp -d)"
  mkdir -p "${WORK}/bin" "${WORK}/cache"
  cat > "${WORK}/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "${CALLS}"
case "$1 $2" in
  "load "*|"load")
    while read -r tag; do echo "Loaded image: $tag"; done ;;
  "image inspect")
    echo "sha256:${!#}" ;;
  "manifest inspect")
    # STUB_PUBLISHED: "<tag>=<image id>" pairs already in the registry.
    for entry in ${STUB_PUBLISHED:-}; do
      if [[ "${entry%%=*}" == "${!#}" ]]; then
        echo "{\"config\": {\"digest\": \"${entry#*=}\"}}"
        exit 0
      fi
    done
    exit 1 ;;
esac
exit 0
STUB
  cat > "${WORK}/bin/zstd" <<'STUB'
#!/usr/bin/env bash
cat "$2"
STUB
  chmod +x "${WORK}/bin/docker" "${WORK}/bin/zstd"
}
teardown () { rm -rf "$WORK"; }

# archive <build> <service> <tag>...
archive () {
  local build="$1" service="$2"
  shift 2
  mkdir -p "${WORK}/cache/${build}/docker-images/${service}"
  printf '%s\n' "$@" > "${WORK}/cache/${build}/docker-images/${service}/${1##*:}.tar.zst"
}

# run [VAR=value...]: exit code in RC, output in OUT, docker calls in CALLS.
run () {
  export CALLS="${WORK}/calls"
  : > "$CALLS"
  set +e
  OUT="$(env PATH="${WORK}/bin:${PATH}" CACHE_BASE="${WORK}/cache" \
    BUILDKITE_BUILD_ID=pkg "$@" "$SCRIPT" 2>&1)"
  RC=$?
  set -e
}

called () { grep -qx -- "$1" "$CALLS"; }

t_pushes_primary_and_tags_the_rest () {
  archive pkg mina-daemon reg/mina-daemon:1.0.0-devnet reg/mina-daemon:abc-devnet
  run
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "primary not pushed" called "push reg/mina-daemon:1.0.0-devnet"
  expect "extra tag not added registry-side" \
    called "buildx imagetools create --tag reg/mina-daemon:abc-devnet reg/mina-daemon:1.0.0-devnet"
}

t_refuses_a_tag_holding_another_image () {
  archive pkg mina-daemon reg/mina-daemon:1.0.0-devnet
  archive pkg mina-archive reg/mina-archive:1.0.0-devnet
  run STUB_PUBLISHED="reg/mina-archive:1.0.0-devnet=sha256:other"
  expect "must refuse" test $RC -ne 0
  expect "nothing may be pushed once one tag is refused" not grep -q "^push" "$CALLS"
}

t_skips_a_tag_already_holding_this_image () {
  archive pkg mina-daemon reg/mina-daemon:1.0.0-devnet
  archive pkg mina-archive reg/mina-archive:1.0.0-devnet
  run STUB_PUBLISHED="reg/mina-daemon:1.0.0-devnet=sha256:reg/mina-daemon:1.0.0-devnet"
  expect "a retry must succeed: $OUT" test $RC -eq 0
  expect "already published, must be skipped" not called "push reg/mina-daemon:1.0.0-devnet"
  expect "the rest must be pushed" called "push reg/mina-archive:1.0.0-devnet"
}

t_force_overwrites () {
  archive pkg mina-daemon reg/mina-daemon:1.0.0-devnet
  run STUB_PUBLISHED="reg/mina-daemon:1.0.0-devnet=sha256:other" FORCE_DOCKER_OVERWRITE=1
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "must overwrite" called "push reg/mina-daemon:1.0.0-devnet"
}

t_nothing_to_publish_fails () {
  run
  expect "no images must be an error" test $RC -ne 0
}

t_reads_the_generic_build_too () {
  archive pkg mina-daemon reg/mina-daemon:1.0.0-devnet
  archive gen mina-daemon reg/mina-daemon:1.0.0-generic
  run MINA_GENERIC_CACHE_ROOT=gen
  expect "generic image not published" called "push reg/mina-daemon:1.0.0-generic"
  expect "network image not published" called "push reg/mina-daemon:1.0.0-devnet"
}

t_read_cache_root_names_the_packaging_build () {
  archive other mina-daemon reg/mina-daemon:1.0.0-devnet
  run MINA_READ_CACHE_ROOT=other
  expect "MINA_READ_CACHE_ROOT not read" called "push reg/mina-daemon:1.0.0-devnet"
}

t_dry_run_pushes_nothing () {
  archive pkg mina-daemon reg/mina-daemon:1.0.0-devnet
  run DRY_RUN=1
  expect "exit $RC" test $RC -eq 0
  expect "dry run pushed" not grep -qE "^(push|buildx)" "$CALLS"
}

for t in t_pushes_primary_and_tags_the_rest t_refuses_a_tag_holding_another_image \
         t_skips_a_tag_already_holding_this_image t_force_overwrites \
         t_nothing_to_publish_fails t_reads_the_generic_build_too \
         t_read_cache_root_names_the_packaging_build t_dry_run_pushes_nothing; do
  echo "TEST: $t"
  setup
  "$t"
  teardown
done

echo "Results: ${PASSED} passed, ${FAILED} failed"
[[ $FAILED -eq 0 ]]

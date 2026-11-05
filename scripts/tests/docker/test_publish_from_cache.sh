#!/usr/bin/env bash

# Tests for buildkite/scripts/docker/publish_from_cache.sh, against stub docker
# and zstd. An archive is a text file with one tag on each line; the stub
# "loads" it by printing those tags, and gives each image the ID "sha256:<tag>".

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
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
  # Archives go in name order: archive, daemon, rosetta. The run stops at the
  # refused one; what came before it is published, what comes after is not.
  archive pkg mina-archive reg/mina-archive:1.0.0-devnet
  archive pkg mina-daemon reg/mina-daemon:1.0.0-devnet
  archive pkg mina-rosetta reg/mina-rosetta:1.0.0-devnet
  run STUB_PUBLISHED="reg/mina-daemon:1.0.0-devnet=sha256:other"
  expect "must refuse" test $RC -ne 0
  expect "the archive before the refusal is published" called "push reg/mina-archive:1.0.0-devnet"
  expect "the refused tag must not be pushed" not called "push reg/mina-daemon:1.0.0-devnet"
  expect "nothing after the refusal may be pushed" not called "push reg/mina-rosetta:1.0.0-devnet"
}

t_publishes_one_archive_at_a_time () {
  # Each image is loaded, pushed and dropped before the next one is loaded, so
  # the local store never holds more than the image being pushed.
  archive pkg mina-archive reg/mina-archive:1.0.0-devnet
  archive pkg mina-daemon reg/mina-daemon:1.0.0-devnet reg/mina-daemon:abc-devnet
  run
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "first image not dropped" called "image rm --no-prune reg/mina-archive:1.0.0-devnet"
  expect "second image not dropped with both tags" \
    called "image rm --no-prune reg/mina-daemon:1.0.0-devnet reg/mina-daemon:abc-devnet"
  expect "second load must come after the first push" \
    test "$(grep -n -m1 '^load' "$CALLS" | cut -d: -f1)" -lt "$(grep -n -m1 '^push reg/mina-archive' "$CALLS" | cut -d: -f1)"
  expect "second load must come after the first push" \
    test "$(grep -n '^load' "$CALLS" | sed -n 2p | cut -d: -f1)" -gt "$(grep -n -m1 '^push reg/mina-archive' "$CALLS" | cut -d: -f1)"
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

t_publishes_release_services_only () {
  # The auto-hardfork image and the delegation verifier are in the cache, as
  # the packaging stage builds them, but a release does not push them.
  archive pkg mina-daemon reg/mina-daemon:1.0.0-devnet
  archive pkg mina-daemon-auto-hardfork reg/mina-daemon-auto-hardfork:1.0.0-devnet
  archive gen mina-delegation-verifier reg/mina-delegation-verifier:1.0.0-bookworm
  run MINA_GENERIC_CACHE_ROOT=gen
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "release image not pushed" called "push reg/mina-daemon:1.0.0-devnet"
  expect "auto-hardfork image must not be pushed" not called "push reg/mina-daemon-auto-hardfork:1.0.0-devnet"
  expect "delegation verifier must not be pushed" not called "push reg/mina-delegation-verifier:1.0.0-bookworm"
  expect "skipped archives must be listed" grep -q "mina-daemon-auto-hardfork/1.0.0-devnet" <<< "$OUT"
}

t_release_dockers_names_the_services () {
  archive pkg mina-daemon reg/mina-daemon:1.0.0-devnet
  archive pkg mina-daemon-auto-hardfork reg/mina-daemon-auto-hardfork:1.0.0-devnet
  run MINA_RELEASE_DOCKERS=mina-daemon-auto-hardfork
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "named service not pushed" called "push reg/mina-daemon-auto-hardfork:1.0.0-devnet"
  expect "unnamed service must not be pushed" not called "push reg/mina-daemon:1.0.0-devnet"
}

t_release_docker_tags_narrows_the_variants () {
  archive pkg mina-daemon reg/mina-daemon:1.0.0-noble-devnet
  archive pkg mina-daemon reg/mina-daemon:1.0.0-noble-devnet-generic
  archive pkg mina-daemon reg/mina-daemon:1.0.0-noble-lightnet
  archive pkg mina-daemon reg/mina-daemon:1.0.0-focal-devnet
  archive pkg mina-archive reg/mina-archive:1.0.0-noble-devnet
  run MINA_RELEASE_DOCKER_TAGS="*-noble-devnet, *-jammy-devnet"
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "matching daemon tag not pushed" called "push reg/mina-daemon:1.0.0-noble-devnet"
  expect "matching archive tag not pushed" called "push reg/mina-archive:1.0.0-noble-devnet"
  expect "generic variant must not be pushed" not called "push reg/mina-daemon:1.0.0-noble-devnet-generic"
  expect "lightnet must not be pushed" not called "push reg/mina-daemon:1.0.0-noble-lightnet"
  expect "other codename must not be pushed" not called "push reg/mina-daemon:1.0.0-focal-devnet"
}

t_no_release_image_fails () {
  archive pkg mina-daemon-auto-hardfork reg/mina-daemon-auto-hardfork:1.0.0-devnet
  run
  expect "only non-release images must be an error" test $RC -ne 0
  expect "nothing may be pushed" not grep -q "^push" "$CALLS"
}

t_target_registry_retags_and_pushes_there () {
  archive pkg mina-daemon reg/mina-daemon:1.0.0-devnet reg/mina-daemon:abc-devnet
  run MINA_PUBLISH_TARGET_REGISTRY=other/repo
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "primary not retagged" called "tag reg/mina-daemon:1.0.0-devnet other/repo/mina-daemon:1.0.0-devnet"
  expect "retagged primary not pushed" called "push other/repo/mina-daemon:1.0.0-devnet"
  expect "extra tag not added in the target registry" \
    called "buildx imagetools create --tag other/repo/mina-daemon:abc-devnet other/repo/mina-daemon:1.0.0-devnet"
  expect "the tag it was built for must not be pushed" not called "push reg/mina-daemon:1.0.0-devnet"
  expect "loaded and retagged images not dropped" \
    called "image rm --no-prune reg/mina-daemon:1.0.0-devnet reg/mina-daemon:abc-devnet other/repo/mina-daemon:1.0.0-devnet other/repo/mina-daemon:abc-devnet"
}

t_target_registry_equal_to_the_tagged_one_pushes_as_tagged () {
  archive pkg mina-daemon reg/mina-daemon:1.0.0-devnet
  run MINA_PUBLISH_TARGET_REGISTRY=reg
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "must not retag onto itself" not grep -q "^tag " "$CALLS"
  expect "not pushed as tagged" called "push reg/mina-daemon:1.0.0-devnet"
}

t_mirror_tags_narrow_the_mirror_only () {
  # A release pushes every codename to its registry and one to the mirror.
  archive pkg mina-daemon reg/mina-daemon:1.0.0-noble-mainnet
  archive pkg mina-daemon reg/mina-daemon:1.0.0-bookworm-mainnet
  run MINA_RELEASE_DOCKER_TAGS="*-mainnet" MINA_RELEASE_DOCKER_MIRROR_TAGS="*-noble-mainnet"
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "without a target the mirror tags must not apply" called "push reg/mina-daemon:1.0.0-bookworm-mainnet"
  run MINA_RELEASE_DOCKER_TAGS="*-mainnet" MINA_RELEASE_DOCKER_MIRROR_TAGS="*-noble-mainnet" MINA_PUBLISH_TARGET_REGISTRY=other
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "mirrored codename not pushed" called "push other/mina-daemon:1.0.0-noble-mainnet"
  expect "other codename must not reach the mirror" not called "push other/mina-daemon:1.0.0-bookworm-mainnet"
  expect "skipped image must be listed" grep -q "mina-daemon/1.0.0-bookworm-mainnet" <<< "$OUT"
}

t_mirror_without_mirror_tags_takes_the_release_tags () {
  archive pkg mina-daemon reg/mina-daemon:1.0.0-noble-mainnet
  archive pkg mina-daemon reg/mina-daemon:1.0.0-noble-devnet
  run MINA_RELEASE_DOCKER_TAGS="*-mainnet" MINA_PUBLISH_TARGET_REGISTRY=other
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "release tag not mirrored" called "push other/mina-daemon:1.0.0-noble-mainnet"
  expect "non-release tag must not be mirrored" not called "push other/mina-daemon:1.0.0-noble-devnet"
}

for t in t_pushes_primary_and_tags_the_rest t_refuses_a_tag_holding_another_image \
         t_publishes_one_archive_at_a_time \
         t_skips_a_tag_already_holding_this_image t_force_overwrites \
         t_nothing_to_publish_fails t_reads_the_generic_build_too \
         t_read_cache_root_names_the_packaging_build t_dry_run_pushes_nothing \
         t_publishes_release_services_only t_release_dockers_names_the_services \
         t_release_docker_tags_narrows_the_variants t_no_release_image_fails \
         t_target_registry_retags_and_pushes_there \
         t_target_registry_equal_to_the_tagged_one_pushes_as_tagged \
         t_mirror_tags_narrow_the_mirror_only \
         t_mirror_without_mirror_tags_takes_the_release_tags; do
  echo "TEST: $t"
  setup
  "$t"
  teardown
done

echo "Results: ${PASSED} passed, ${FAILED} failed"
[[ $FAILED -eq 0 ]]

#!/bin/bash

# The hardfork package pipeline, rendered as the Buildkite pipeline renders it
# (run-hardfork-package-gen.sh), checked for the properties a fork-day run
# relies on:
#
#   - every depends_on names a step of the pipeline (build 1314 stalled on a
#     key no step had);
#   - no image step pushes: each one builds --load-only and writes the image
#     to this build's cache, where the publish pipeline reads it;
#   - the verification steps load the daemon image from that cache;
#   - MINA_RELEASE_DOCKER_REPO and MINA_RELEASE_CHANNEL, the variables the
#     release pipelines read, reach the image tags and the package Suite;
#   - a run that takes the generic images from a version in the registry does
#     not look for their bases in the cache.
#
# Needs dhall-to-yaml, as the render does.

set -euo pipefail

cd "$(dirname "$0")/../../../.."

FAILED=0
fail() { echo "  ❌ $1"; FAILED=1; }
ok() { echo "  ✅ $1"; }

# expect <label> <command...>: the command exits 0
expect() {
  local label="$1"
  shift
  if "$@"; then ok "$label"; else fail "$label"; fi
}

# expect_not <label> <command...>: the command exits non-zero
expect_not() {
  local label="$1"
  shift
  if "$@"; then fail "$label"; else ok "$label"; fi
}

CLEAN=(env -u MINA_RELEASE_CHANNEL -u MINA_RELEASE_DOCKER_REPO -u MINA_RELEASE_DOCKER_MIRROR
       -u MINA_RELEASE_DEBIAN_REPO -u MINA_RELEASE_DEBIAN_MIRROR
       -u USE_GENERIC_DOCKERS_FROM_VERSION -u USE_ARTIFACTS_FROM_BUILDKITE_BUILD)

# render <VAR=value>...: the pipeline YAML for a mainnet noble run
render() {
  "${CLEAN[@]}" "$@" \
    CODENAMES_CONFIG=Noble_Amd64 NETWORK=Mainnet \
    GENESIS_TIMESTAMP=2026-10-29T18:00:00Z \
    CONFIG_JSON_GZ_URL=https://example.invalid/config.json.gz \
    PRECOMPUTED_FORK_BLOCK_PREFIX=gs://example/mainnet \
    ./buildkite/scripts/entrypoints/run-hardfork-package-gen.sh 2>/dev/null
}

keys() { grep -o "'key': '[^']*'" | sed "s/'key': '//; s/'$//" | sort -u; }

# Each build.sh invocation is one line of the YAML. Every command is also
# echoed ("-- Running: ...") by the step; those lines are left out.
commands() { grep -v -- '-- Running:'; }
build_lines() { commands | grep -o "\./scripts/docker/build\.sh[^']*" || true; }

echo "TEST: every dependency names a step of the pipeline"
yaml="$(render)"
undefined="$(comm -23 \
  <(grep -oE "_GenerateHardforkPackage-[A-Za-z0-9_-]+" <<< "$yaml" | sort -u) \
  <(keys <<< "$yaml"))"
expect "no undefined depends_on target (got: ${undefined:-none})" test -z "$undefined"
expect "the profiled daemon step is there" grep -q "daemon_profile-mainnet-noble-docker-image" <<< "$yaml"

echo "TEST: no image step pushes; every image goes to this build's cache"
builds="$(build_lines <<< "$yaml")"
n="$(grep -c . <<< "$builds")"
expect "image steps rendered (got $n)" test "$n" -ge 5
expect "every build is --load-only" test "$(grep -c -- '--load-only' <<< "$builds")" -eq "$n"
expect "every build writes to the build cache" \
  test "$(grep -c -- '--build-cache-dir /var/storagebox/[^ ]*BUILDKITE_BUILD_ID[^ ]*/docker-images' <<< "$builds")" -eq "$n"
expect "layered bases come from the build cache" \
  test "$(grep -c -- '--base-cache-dir /var/storagebox/[^ ]*BUILDKITE_BUILD_ID[^ ]*/docker-images' <<< "$builds")" -eq "$n"
expect_not "no step pushes the image after the build" grep -q "docker push" <<< "$yaml"

echo "TEST: the verification steps load the daemon image from the build cache"
loads="$(commands <<< "$yaml" | grep -c "CACHE_ROOT=/var/storagebox/[^ ]*BUILDKITE_BUILD_ID[^ ]*/docker-images ./buildkite/scripts/docker/load_from_cache.sh europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-daemon:" || true)"
expect "four verification steps load the image (got $loads)" test "$loads" -eq 4

echo "TEST: the hardfork default is the euro registry, unstable channel"
expect "images tagged for the euro registry" \
  test "$(grep -c -- '--docker-registry europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo' <<< "$builds")" -eq "$n"
expect_not "internal registry keeps the hash tag" grep -q -- '--no-hash-tag' <<< "$builds"
expect "config packages built for unstable" grep -q "MINA_DEB_RELEASE=unstable" <<< "$yaml"
expect "images built from the unstable packages" test "$(grep -c -- '--deb-release unstable' <<< "$builds")" -eq "$n"

echo "TEST: MINA_RELEASE_DOCKER_REPO and MINA_RELEASE_CHANNEL reach the render"
yaml="$(render MINA_RELEASE_DOCKER_REPO='< Internal | InternalEurope | Public >.Public' MINA_RELEASE_CHANNEL=stable)"
builds="$(build_lines <<< "$yaml")"
expect "images tagged for docker.io" \
  test "$(grep -c -- '--docker-registry docker.io/minaprotocol' <<< "$builds")" -eq "$n"
expect "docker.io gets no hash tag" test "$(grep -c -- '--no-hash-tag' <<< "$builds")" -eq "$n"
expect "verification loads the docker.io-tagged image" \
  grep -q "load_from_cache.sh docker.io/minaprotocol/mina-daemon:" <<< "$yaml"
expect "config packages built for stable" grep -q "MINA_DEB_RELEASE=stable" <<< "$yaml"
expect "images built from the stable packages" test "$(grep -c -- '--deb-release stable' <<< "$builds")" -eq "$n"
expect "still nothing pushed" test "$(grep -c -- '--load-only' <<< "$builds")" -eq "$n"

echo "TEST: a misspelled release variable stops the render"
if "${CLEAN[@]}" MINA_RELEASE_DOCKER_REPO='< Internal | InternalEurope | Public >.Pubic' \
    CODENAMES_CONFIG=Noble_Amd64 NETWORK=Mainnet CONFIG_JSON_GZ_URL=https://example.invalid/c.json.gz \
    ./buildkite/scripts/entrypoints/run-hardfork-package-gen.sh > /dev/null 2>&1; then
  fail "a typo in MINA_RELEASE_DOCKER_REPO must fail the render"
else
  ok "a typo in MINA_RELEASE_DOCKER_REPO fails the render"
fi

echo "TEST: generic images from a version in the registry: no cached base"
yaml="$(render USE_GENERIC_DOCKERS_FROM_VERSION=4.0.4-c9e2eac)"
builds="$(build_lines <<< "$yaml")"
n="$(grep -c . <<< "$builds")"
expect "only the configured images are built (got $n)" test "$n" -eq 3
expect_not "no --base-cache-dir: the base is pulled" grep -q -- '--base-cache-dir' <<< "$builds"
expect "the configured images still go to the build cache" \
  test "$(grep -c -- '--build-cache-dir' <<< "$builds")" -eq "$n"
expect "verification loads the versioned image" \
  grep -q "load_from_cache.sh europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-daemon:4.0.4-c9e2eac-noble-mainnet" <<< "$yaml"

if [[ "$FAILED" -ne 0 ]]; then
  echo "❌ test_hardfork_render: failures"
  exit 1
fi
echo "✅ test_hardfork_render: all passed"

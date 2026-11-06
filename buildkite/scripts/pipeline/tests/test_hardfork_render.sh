#!/bin/bash

# The hardfork package pipeline, rendered as the Buildkite pipeline renders it
# (run-hardfork-package-gen.sh), checked for the properties a fork-day run
# relies on:
#
#   - every depends_on names a step of the pipeline (build 1314 stalled on a
#     key no step had);
#   - every image step pushes to the internal euro registry, never to the
#     public one, and writes the image to this build's cache, where the
#     fork-day publish reads it;
#   - the verification steps load the daemon image from that cache;
#   - MINA_RELEASE_CHANNEL, the variable the release pipelines read, reaches
#     the package Suite, and MINA_RELEASE_DOCKER_REPO does not reach the tags;
#   - a run that takes the generic images from a version in the registry does
#     not look for their bases in the cache;
#   - the verification steps wait for the reference ledgers they read.
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

# render <VAR=value>...: the pipeline YAML for a mainnet noble run. dhall-to-yaml
# 1.6 quotes the keys and step names with ', 1.7 with ". The checks read ', so
# they pass with both.
render() {
  "${CLEAN[@]}" "$@" \
    CODENAMES_CONFIG=Noble_Amd64 NETWORK=Mainnet \
    GENESIS_TIMESTAMP=2026-10-29T18:00:00Z \
    CONFIG_JSON_GZ_URL=https://example.invalid/config.json.gz \
    PRECOMPUTED_FORK_BLOCK_PREFIX=gs://example/mainnet \
    ./buildkite/scripts/entrypoints/run-hardfork-package-gen.sh 2>/dev/null \
    | sed -E "s/^( *(- )?'(key|step)': )\"([^\"]*)\"$/\1'\4'/"
}

keys() { grep -oE "'key': [\"'][^\"']*[\"']" | sed -E "s/'key': [\"']//; s/[\"']\$//" | sort -u; }

# deps_of <key>: the depends_on targets of the step with that key in $yaml,
# one per line. A step is one "  - " item of the quoted YAML; each of its
# depends_on entries is an item holding a "'step': '...'" line.
deps_of() {
  awk -v want="$1" <<< "$yaml" '
    /^  - / { if (key == want) printf "%s", deps; key = ""; deps = ""; indeps = 0 }
    /^    .depends_on.:/ { indeps = 1; next }
    /^    [^ ]/ { indeps = 0 }
    indeps && /^        .step.: / { sub(/^        .step.: \x27/, ""); sub(/\x27$/, ""); deps = deps $0 "\n" }
    /^    .key.: / { sub(/^    .key.: \x27/, ""); sub(/\x27$/, ""); key = $0 }
    END { if (key == want) printf "%s", deps }
  ' | grep . || true
}

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

echo "TEST: every image is pushed to the euro registry and written to this build's cache"
builds="$(build_lines <<< "$yaml")"
n="$(grep -c . <<< "$builds")"
expect "image steps rendered (got $n)" test "$n" -ge 5
expect_not "no build is --load-only: every image is pushed" grep -q -- '--load-only' <<< "$builds"
expect "every build writes to the build cache" \
  test "$(grep -c -- '--build-cache-dir /var/storagebox/[^ ]*BUILDKITE_BUILD_ID[^ ]*/docker-images' <<< "$builds")" -eq "$n"
expect "layered bases come from the build cache" \
  test "$(grep -c -- '--base-cache-dir /var/storagebox/[^ ]*BUILDKITE_BUILD_ID[^ ]*/docker-images' <<< "$builds")" -eq "$n"

echo "TEST: the verification steps load the daemon image from the build cache"
loads="$(commands <<< "$yaml" | grep -c "CACHE_ROOT=/var/storagebox/[^ ]*BUILDKITE_BUILD_ID[^ ]*/docker-images ./buildkite/scripts/docker/load_from_cache.sh europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-daemon:" || true)"
expect "four verification steps load the image (got $loads)" test "$loads" -eq 4

echo "TEST: the registry is the euro one; the default channel is unstable"
expect "images tagged for the euro registry" \
  test "$(grep -c -- '--docker-registry europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo' <<< "$builds")" -eq "$n"
expect_not "internal registry keeps the hash tag" grep -q -- '--no-hash-tag' <<< "$builds"
expect "config packages built for unstable" grep -q "MINA_DEB_RELEASE=unstable" <<< "$yaml"
expect "images built from the unstable packages" test "$(grep -c -- '--deb-release unstable' <<< "$builds")" -eq "$n"

echo "TEST: MINA_RELEASE_CHANNEL reaches the render; MINA_RELEASE_DOCKER_REPO does not"
yaml="$(render MINA_RELEASE_DOCKER_REPO='< Internal | InternalEurope | Public >.Public' MINA_RELEASE_CHANNEL=stable)"
builds="$(build_lines <<< "$yaml")"
expect "images still tagged for the euro registry, never docker.io" \
  test "$(grep -c -- '--docker-registry europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo' <<< "$builds")" -eq "$n"
expect_not "no image is tagged for docker.io" grep -q -- '--docker-registry docker.io' <<< "$builds"
expect_not "verification does not look for a docker.io-tagged image" \
  grep -q "load_from_cache.sh docker.io/" <<< "$yaml"
expect "config packages built for stable" grep -q "MINA_DEB_RELEASE=stable" <<< "$yaml"
expect "images built from the stable packages" test "$(grep -c -- '--deb-release stable' <<< "$builds")" -eq "$n"

echo "TEST: a misspelled release variable in the environment stops the render"
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

echo "TEST: the verification steps wait for the reference ledgers they read"
yaml="$(render)"
for check in config ledgers tarballs; do
  expect "the $check check waits for the reference step" \
    grep -qx "_GenerateHardforkPackage-generate-reference-tarballs-noble" <<< "$(deps_of "_GenerateHardforkPackage-verify-packaged-artifacts-$check-noble")"
done
expect "the corrupted-artifacts check waits for it too" \
  grep -qx "_GenerateHardforkPackage-generate-reference-tarballs-noble" <<< "$(deps_of "_GenerateHardforkPackage-assert-unverify-corrupted-packaged-artifacts-noble")"
expect "the packaging waits for the generation step" \
  grep -qx "_GenerateHardforkPackage-generate-hardfork-tarballs-noble" <<< "$(deps_of "_GenerateHardforkPackage-build-hf-debian")"

if [[ "$FAILED" -ne 0 ]]; then
  echo "❌ test_hardfork_render: failures"
  exit 1
fi
echo "✅ test_hardfork_render: all passed"

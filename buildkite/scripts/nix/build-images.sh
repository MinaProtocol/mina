#!/usr/bin/env bash

# Build the daemon/archive docker images with Nix instead of from Debian
# packages, and put them in the shared CI cache the integration tests already
# read from (buildkite/scripts/docker/load_from_cache.sh).
#
# Why: IntegrationTestDockerImages builds those two images by installing the
# freshly-built .debs, which is what ties the integration tests to the whole
# debian+docker packaging pipeline. nix/docker.nix already describes the same
# two images (mina-image-full, mina-archive-image-full) straight from the
# compiled binaries, and `nix build tests` already builds mina on every PR into
# a shared binary cache -- so the images can come from there instead, with no
# packages involved at all.
#
# No docker daemon is used anywhere in here, deliberately. This job runs inside
# the nixos container, and Cmds.dhall mounts only /var/storagebox, /var/secrets,
# /shared and the checkout into it -- there is no docker socket, so `docker
# load` / `docker run` / `docker save` are not available (that is what killed
# the first version of this script). It does not need them: streamLayeredImage
# emits a docker-archive tarball on stdout, which is exactly the format
# load_from_cache.sh feeds back into `docker load` on an agent that does have a
# daemon. So the image goes store -> stream -> zstd -> cache in one pass.
#
# This script deliberately does NOT overwrite the images the integration tests
# currently consume: it writes to <service>-nix so its output can be compared
# against the .deb-built images without disturbing them. The suffix stays until
# the tests are switched over, which is a separate change.
#
# Usage: build-images.sh
# Env:
#   MINA_DEB_CODENAME  codename segment of the cache tag (default bullseye)
#   CACHE_ROOT         cache root (default /var/storagebox/docker-cache)
#   DOCKER_REGISTRY    registry prefix baked into the image name

set -euo pipefail

CODENAME="${MINA_DEB_CODENAME:-bullseye}"
CACHE_ROOT="${CACHE_ROOT:-/var/storagebox/docker-cache}"

# The images are never pushed anywhere, but they still have to carry the
# registry-prefixed name, because that is the name their consumer asks docker
# for. scripts/docker/helper.sh builds the .deb-based images as
# "${DOCKER_REGISTRY}/${SERVICE}:${TAG}" and run-test-executive-local.sh passes
# that same full reference to test_executive. A bare "mina-daemon-nix:tag" would
# load fine and then be invisible under the name the swarm looks up, sending it
# to the registry for an image that was never pushed.
DOCKER_REGISTRY="${DOCKER_REGISTRY:-europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo}"

# Parameter expansion rather than $(dirname ...): this runs before the nix shell
# below, and dirname is coreutils, which this container does not necessarily
# have. Everything above the re-exec has to be builtins only.
SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# shellcheck source=buildkite/scripts/nix/lib.sh
source "$SCRIPT_DIR/lib.sh"

# This container ships a bare PATH: nix and git, but no coreutils, no sed, no
# zstd, no python3. That is what killed the previous version of this script,
# which sourced scripts/export-git-env-vars.sh and died on "sed: command not
# found" (exit 127). Rather than guess which utilities happen to be there, bring
# a known set in with nix and re-run this script inside it. This has to be the
# first thing that happens, so nothing below has to care.
if [[ "${NIX_IMAGES_TOOLS_READY:-0}" != "1" ]]; then
  export NIX_IMAGES_TOOLS_READY=1
  exec nix "${NIX_OPTS[@]}" shell \
    nixpkgs#bash nixpkgs#coreutils nixpkgs#zstd nixpkgs#python3 \
    --command bash "$0" "$@"
fi

# Fixes up the way Buildkite hands us the checkout (see lib.sh). It chowns
# the tree and rewrites the current branch, which has no business happening on a
# developer machine -- guarding it is what makes this script runnable locally
# against the same images CI produces.
if [[ -n "${BUILDKITE:-}" ]]; then
  prepare_nix_workdir
fi

# Only GITHASH is needed out of export-git-env-vars.sh, and git alone can
# produce it. Keep the semantics identical to that script: an 8-character hash
# with the last character dropped.
GITHASH_CONFIG=$(git rev-parse --short=8 --verify HEAD)
GITHASH=${GITHASH_CONFIG%?}
echo "Building images for ${GITHASH} (${CODENAME})"

# The devnet attrs, not mina-image-full/mina-archive-image-full: those are built
# from the dev profile and label themselves mainnet, whereas the integration
# tests want devnet binaries with a matching PROFILE hint. They also share their
# derivation with `nix build .#devnet`, which NixBuildTest already runs on every
# PR, so the mina compile itself should come out of the shared nix cache. The
# attribute names line up with the cache tags on purpose: -generic for the
# config-free daemon, plain -devnet for the archive, same as the Debian packages.
#
# <flake attr>|<cache service>|<cache tag>|<runtime contract>|<expected profile>
# The archive image carries no PROFILE hint, so it has nothing to assert.
IMAGES=(
  "mina-image-devnet-generic|mina-daemon-nix|${GITHASH}-${CODENAME}-devnet-generic|daemon|devnet"
  "mina-archive-image-devnet|mina-archive-nix|${GITHASH}-${CODENAME}-devnet|archive|"
)

for entry in "${IMAGES[@]}"; do
  IFS='|' read -r attr service tag contract profile <<< "$entry"

  echo "--- Building ${attr} with nix"
  # streamLayeredImage produces a SCRIPT that writes a docker-archive tarball to
  # stdout, rather than a tarball in the store -- so it is piped, not copied.
  #
  # --no-link, emphatically: an out-link is an untracked file in the checkout,
  # which makes the flake tree dirty, which makes nix resolve the revision as
  # "<dirty>" and bake that into MINA_COMMIT_SHA1. Building the first image
  # would then change the version stamped into the second one.
  stream=$(nix "${NIX_OPTS[@]}" build --no-link --print-out-paths \
    "$PWD?submodules=1#${attr}" | tail -n1)

  # Registry-prefixed name inside the image, bare service name for the cache
  # path -- load_from_cache.sh takes the last path component of the reference to
  # find the file, so the two stay consistent.
  target="${DOCKER_REGISTRY}/${service}:${tag}"
  out="${CACHE_ROOT}/${service}/${tag}.tar.zst"
  mkdir -p "$(dirname "$out")"

  # --repo_tag overrides the RepoTags baked into the archive, which otherwise
  # say "mina-full:<nix output hash>". load_from_cache.sh looks the image up by
  # name after `docker load`, so the archive has to carry the name the cache
  # filename implies, not the one nix picked.
  #
  # Write to a temp file next to the target and rename: a job killed mid-write
  # would otherwise leave a truncated .tar.zst in the shared cache that later
  # builds would happily try to load.
  echo "--- Streaming ${target} into the CI cache"
  tmp="${out}.$$.partial"
  trap 'rm -f "$tmp"' EXIT
  # shellcheck disable=SC2086 # $profile is deliberately unquoted: empty means
  # "no profile hint to assert", and an empty quoted arg would be a bad one.
  "$stream" --repo_tag "$target" \
    | ./buildkite/scripts/nix/verify_image.py "$contract" $profile \
    | zstd -T0 -3 -o "$tmp"
  mv "$tmp" "$out"
  trap - EXIT

  ls -la "$out"
done

echo "✅ Nix-built daemon and archive images are in ${CACHE_ROOT}"

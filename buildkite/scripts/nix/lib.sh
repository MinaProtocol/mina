#!/usr/bin/env bash

# Shared setup for the CI jobs that run nix inside the nixos container:
# test.sh (NixBuildTest) and build-images.sh (NixDockerImages), both alongside
# this file.
#
# Both have to fix up the Buildkite checkout the same way before nix can look at
# it, and both had their own copy of that dance -- which is how the image job
# shipped without the ownership fix and failed with exit 128 until it was
# rediscovered. Keep it in one place so the next job to run nix in CI inherits
# the fixes instead of relearning them.
#
# Sourced, not executed.

# Base flags every nix invocation in CI needs. Callers may append their own
# (test.sh adds the binary-cache signing and post-build-hook options).
# shellcheck disable=SC2034 # consumed by the scripts that source this file
NIX_OPTS=(--accept-flake-config --experimental-features 'nix-command flakes')

# Make the Buildkite checkout usable by git, and therefore by nix, which
# resolves the flake through git.
#
# Two separate problems, both fatal, both needing a fix before ANY git command:
#
#   * The checkout is owned by a different user than the one in the container,
#     so git refuses with "detected dubious ownership" (exit 128) and submodule
#     sync reports it is "not owned by current user". The safe.directory
#     wildcard rather than just /workdir because `?submodules=1` makes git read
#     each submodule as a repository in its own right.
#   * Buildkite checks out a detached HEAD, and nix fails to resolve a flake
#     from one ("fatal: reference is not a tree"), so put HEAD back on a branch.
prepare_nix_workdir() {
  chown -R "${USER:-root}" /workdir || true
  git config --global --add safe.directory '*'

  git branch -D "$BUILDKITE_BRANCH" 2>/dev/null || true
  git checkout -b "$BUILDKITE_BRANCH"
  git reset --hard "$BUILDKITE_COMMIT"
}

# Nix binary cache on the Hetzner storage box.
#
# The nixos job container starts with an empty /nix/store every time (it is
# `docker run --rm`), so every job re-downloads the whole dependency closure.
# The only readers of the GCS cache (gs://mina-nix-cache) were these very jobs,
# paying internet egress for a few GiB of NARs per job. The storage box is
# already mounted into every job container (Cmds.dhall mounts /var/storagebox),
# so the cache lives there now, as a plain file:// binary cache, next to the
# docker-cache and the other CI caches.
#
# Reads: added as a substituter below. NARs are signed with the same key as
# before (test.sh passes NIX_CACHE_NAR_SECRET as --secret-key-files), and its
# public key is in flake.nix nixConfig, which --accept-flake-config trusts, so
# nothing else has to change for signature checks.
#
# Writes: test.sh copies the job's whole store there after the build with
# `nix copy --all`. The store only holds what the job used, and `nix copy`
# skips paths the cache already has, so this seeds the cache from whatever the
# first run substituted and after that only uploads new outputs. zstd rather
# than nix's default xz: the uploads are a few GiB per commit and xz is an
# order of magnitude slower to compress for no gain a CI cache would notice.
#
# Guarded on the mount so the scripts still work where there is no storage box
# (buildkite/local/run_job.sh without the sync, a developer's machine).
NIX_STORAGEBOX_CACHE="${NIX_STORAGEBOX_CACHE:-/var/storagebox/nix-cache}"
# shellcheck disable=SC2034 # consumed by test.sh
NIX_STORAGEBOX_CACHE_PUSH_URL="file://${NIX_STORAGEBOX_CACHE}?compression=zstd"
if [[ -d "${NIX_STORAGEBOX_CACHE%/*}" ]]; then
  NIX_OPTS+=(--extra-substituters "file://${NIX_STORAGEBOX_CACHE}")
fi

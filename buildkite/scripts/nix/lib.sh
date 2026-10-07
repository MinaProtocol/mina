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

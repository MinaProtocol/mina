#!/usr/bin/env bash
# Build an auto-hardfork Docker image from two branch references using Nix.
#
# Usage:
#   nix-build.sh --pre-fork-branch <branch> --post-fork-branch <branch>
#
# Prints the loaded Docker image tag to stdout.

set -eux -o pipefail

PRE_FORK_BRANCH=""
POST_FORK_BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pre-fork-branch)  PRE_FORK_BRANCH="$2"; shift 2 ;;
    --post-fork-branch) POST_FORK_BRANCH="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PRE_FORK_BRANCH" || -z "$POST_FORK_BRANCH" ]]; then
  echo "Usage: $0 --pre-fork-branch <branch> --post-fork-branch <branch>" >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)

echo "Building auto-hardfork docker image from branches: pre=$PRE_FORK_BRANCH post=$POST_FORK_BRANCH" >&2
docker_result=$(nix build --impure --expr '
  let
    mina = builtins.getFlake "git+file://'"${REPO_ROOT}"'?submodules=1";
    prefork = builtins.getFlake "git+file://'"${REPO_ROOT}"'?ref='"${PRE_FORK_BRANCH}"'&submodules=1";
    postfork = builtins.getFlake "git+file://'"${REPO_ROOT}"'?ref='"${POST_FORK_BRANCH}"'&submodules=1";
  in mina.lib.x86_64-linux.mkAutoHardforkDocker { inherit prefork postfork; }
' --no-link --print-out-paths --accept-flake-config)

echo "Loading docker image" >&2
DOCKER_IMAGE=$("${docker_result}" | docker load | grep -oP 'Loaded image: \K.*')
echo "$DOCKER_IMAGE"

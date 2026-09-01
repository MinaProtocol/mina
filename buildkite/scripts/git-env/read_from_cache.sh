#!/usr/bin/env bash

# Fetch the git identity pinned by the app build, and print where it landed.
#
# The root is resolved the way restore_build_tree.sh resolves the binaries,
# and in the same order, because the whole point is that the identity and the
# binaries come from one place:
#
#   MINA_APPS_CACHE_ROOT  the app build a packaging-only pipeline is wrapping
#   MINA_READ_CACHE_ROOT  the build a detached publish is publishing
#   BUILDKITE_BUILD_ID    this build, which is where the app build wrote it
#
# A miss is not an error. Plenty of callers run where there is no cache at all
# -- a laptop, a container without the mount, a test -- and they must go on
# deriving the environment from the checkout as they always have. Only a
# corrupt or unreadable pin is an error, and that is export-git-env-vars.sh's
# to report, once it has been told to use one.
#
# Usage: read_from_cache.sh <destination-directory>
#        prints the path of the fetched file, or exits non-zero.

set -euo pipefail

DEST_DIR="${1:?Usage: $0 <destination-directory>}"

GIT_ENV_CACHE_PATH="git-env.json"

if [[ ! -v BUILDKITE_BUILD_ID && -z "${MINA_APPS_CACHE_ROOT:-}${MINA_READ_CACHE_ROOT:-}" ]]; then
  exit 1
fi

ROOT_ARGS=()
if [[ -n "${MINA_APPS_CACHE_ROOT:-}" ]]; then
  ROOT_ARGS=(--root "${MINA_APPS_CACHE_ROOT}")
fi

mkdir -p "$DEST_DIR"

# The cache manager is noisy and exits non-zero on a miss, which here is an
# ordinary outcome rather than a fault.
if ! ./buildkite/scripts/cache/manager.sh read "${ROOT_ARGS[@]}" \
      "$GIT_ENV_CACHE_PATH" "$DEST_DIR" >/dev/null 2>&1; then
  exit 1
fi

FETCHED="${DEST_DIR}/${GIT_ENV_CACHE_PATH}"
[[ -r "$FETCHED" ]] || exit 1

echo "$FETCHED"

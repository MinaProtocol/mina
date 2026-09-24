#!/usr/bin/env bash

# Fetch the git identity pinned for this build, and print where it landed.
#
# One place only: this build's own root. The prepare step put it there before
# any real job started, and it resolved where it came from -- an app build
# being packaged, a build being published, or this checkout -- so no reader has
# to work that out again. See buildkite/scripts/git-env/pin.sh.
#
# A miss is not an error. Plenty of callers run where there is no cache at all
# -- a laptop, a container without the mount, a test -- and they must go on
# deriving the environment from the checkout as they always have. Only a pin
# that exists and is unusable is an error, and that is export-git-env-vars.sh's
# to report once it has been told to use one.
#
# Usage: read_from_cache.sh <destination-directory>
#        prints the path of the fetched file, or exits non-zero.

set -euo pipefail

DEST_DIR="${1:?Usage: $0 <destination-directory>}"

GIT_ENV_CACHE_PATH="git-env.json"

[[ -v BUILDKITE_BUILD_ID ]] || exit 1

mkdir -p "$DEST_DIR"

# The cache manager is noisy and exits non-zero on a miss, which here is an
# ordinary outcome rather than a fault. --root is explicit so that a job with
# MINA_READ_CACHE_ROOT set -- a detached publish -- still reads the pin this
# build resolved, rather than the one belonging to the build it reads debians
# from.
if ! ./buildkite/scripts/cache/manager.sh read --root "${BUILDKITE_BUILD_ID}" \
      "$GIT_ENV_CACHE_PATH" "$DEST_DIR" >/dev/null 2>&1; then
  exit 1
fi

FETCHED="${DEST_DIR}/${GIT_ENV_CACHE_PATH}"
[[ -r "$FETCHED" ]] || exit 1

echo "$FETCHED"

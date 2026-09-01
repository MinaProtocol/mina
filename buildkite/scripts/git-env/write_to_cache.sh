#!/usr/bin/env bash

# Pin the git identity of this build's binaries, next to the binaries.
#
# The app build compiles; every job after it wraps what the app build made. Yet
# each of those jobs re-derives GITHASH, GITTAG and GITBRANCH from its own
# checkout, which is not necessarily the checkout the binaries came from. That
# is how a packaging job puts config_<its own hash>.json into a package whose
# daemon looks for another one, and how a tag pushed mid-build gives a build's
# earlier and later jobs different versions.
#
# So the app build writes what it is, once, and the jobs that consume its
# output read that instead of asking git again. Identity travels with the
# binaries rather than with whoever is handling them.
#
# Written into this build's own cache root, beside apps/ and build-manifest/,
# so a packaging job pointed at those with MINA_APPS_CACHE_ROOT finds this too.
#
# Usage: write_to_cache.sh

set -euo pipefail

GIT_ENV_CACHE_PATH="git-env.json"

# shellcheck disable=SC1090,SC1091
source ./buildkite/scripts/export-git-env-vars.sh

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LOCAL_FILE="${TMP_DIR}/git-env.json"
write_git_env_file "$LOCAL_FILE"

echo "--- Pinning the git environment of this build"
cat "$LOCAL_FILE"

./buildkite/scripts/cache/manager.sh write --override "$LOCAL_FILE" "$GIT_ENV_CACHE_PATH"

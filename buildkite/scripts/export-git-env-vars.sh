#!/bin/bash

# Prefer the identity the app build pinned; a downstream job's own checkout is
# not the commit its binaries came from. A caller-set MINA_GIT_ENV_FILE wins
# over the cache; a miss falls back to deriving from the checkout.
if [[ -z "${MINA_GIT_ENV_FILE:-}" ]]; then
   _GIT_ENV_DIR="$(mktemp -d)"
   if _GIT_ENV_FETCHED="$(./buildkite/scripts/git-env/read_from_cache.sh "$_GIT_ENV_DIR")"; then
      export MINA_GIT_ENV_FILE="$_GIT_ENV_FETCHED"
   else
      rm -rf "$_GIT_ENV_DIR"
   fi
   unset _GIT_ENV_DIR _GIT_ENV_FETCHED
fi

# Export all variables from inner script
set -a

export MINA_DEB_CODENAME=${MINA_DEB_CODENAME:=bookworm}

if [[ -n "$BUILDKITE_BRANCH" ]]; then
   # shellcheck disable=SC1090
   BRANCH_NAME=${BUILDKITE_BRANCH} MINA_DEB_CODENAME=${MINA_DEB_CODENAME} source ./scripts/export-git-env-vars.sh
else 
   MINA_DEB_CODENAME=${MINA_DEB_CODENAME} source ./scripts/export-git-env-vars.sh
fi
set +a

export PROJECT="mina"

set +u
export BUILD_NUM=${BUILDKITE_BUILD_NUM}
export BUILD_URL=${BUILDKITE_BUILD_URL}
set -u
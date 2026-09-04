#!/bin/bash

# Prefer the identity the app build pinned over anything this checkout says.
#
# Every job downstream of the app build wraps binaries it did not compile, so
# asking git here answers a question about the wrong commit: it describes the
# checkout doing the wrapping, not the one that produced what is being wrapped.
# GITHASH_CONFIG is the sharp end of that -- it names the genesis config the
# daemon auto-loads -- but the version and the docker tags come from the same
# place and are wrong in the same way.
#
# MINA_GIT_ENV_FILE set by the caller wins over the cache, so a job can pin an
# identity without one. A miss leaves it unset and ./scripts/export-git-env-vars.sh
# derives everything from the checkout, exactly as before.
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

export MINA_DEB_CODENAME=${MINA_DEB_CODENAME:=bullseye}

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
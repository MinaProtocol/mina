#!/bin/bash

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
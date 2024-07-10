#!/bin/bash
set -eox pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source "${SCRIPTPATH}/export-git-env-vars.sh"

DOWNLOAD_FOLDER=_build

source buildkite/scripts/download-artifact-from-cache.sh \
  $DOWNLOAD_FOLDER $MINA_DEB_CODENAME -r

# check for AWS Creds
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "WARNING: AWS_ACCESS_KEY_ID not set, publish commands not run"
    exit 0
fi

source scripts/publish-deb.sh \
  --names "${DOWNLOAD_FOLDER}/mina-*.deb" \
  --release $MINA_DEB_RELEASE \
  --version $MINA_DEB_VERSION \
  --codename $MINA_DEB_CODENAME  

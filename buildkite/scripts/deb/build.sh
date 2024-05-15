#!/bin/bash
set -eo pipefail

# Load in env vars for githash/branch/etc.
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

source "${SCRIPTPATH}/../export-git-env-vars.sh"
cd "${SCRIPTPATH}/../../_build"

source scripts/deb/build.sh \
  --release $MINA_DEB_RELEASE \
  --version $MINA_DEB_VERSION \
  --codename $MINA_DEB_CODENAME  

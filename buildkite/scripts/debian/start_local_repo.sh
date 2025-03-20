#!/bin/bash

if [ -z $MINA_DEB_CODENAME ]; then 
    echo "MINA_DEB_CODENAME env var is not defined"
    exit 1
fi

LOCAL_DEB_FOLDER=_build

set -eou pipefail
set -x


apt-get update 
apt-get install -y aptly

# Download locally static debians (for example mina-legacy )

mkdir -p $LOCAL_DEB_FOLDER
source ./buildkite/scripts/export-git-env-vars.sh
./buildkite/scripts/cache/manager.sh read --root debs "$MINA_DEB_CODENAME/*" _build
./buildkite/scripts/cache/manager.sh read "debians/$MINA_DEB_CODENAME/*" _build
./scripts/debian/aptly.sh start --codename $MINA_DEB_CODENAME --debians $LOCAL_DEB_FOLDER --component unstable --clean --background
#!/bin/bash

if [ -z $MINA_DEB_CODENAME ]; then 
    echo "MINA_DEB_CODENAME env var is not defined"
    exit -1
fi

LOCAL_DEB_FOLDER=_build

set -eou pipefail
set -x


apt-get update 
apt-get install -y aptly

# Download locally static debians (for example mina-legacy )

mkdir -p $LOCAL_DEB_FOLDER
gsutil -m cp "gs://buildkite_k8s/coda/shared/debs/$MINA_DEB_CODENAME/*" $LOCAL_DEB_FOLDER
source ./buildkite/scripts/export-git-env-vars.sh
source ./buildkite/scripts/download-artifact-from-cache.sh _build $MINA_DEB_CODENAME -r 
source ./scripts/debian/aptly.sh start --codename $MINA_DEB_CODENAME --debians $LOCAL_DEB_FOLDER --component unstable --clean --background
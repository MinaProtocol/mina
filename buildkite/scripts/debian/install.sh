#!/bin/bash

if [ -z $MINA_DEB_CODENAME ]; then 
    echo "MINA_DEB_CODENAME env var is not defined"
    exit -1
fi


LOCAL_DEB_FOLDER=_build

source ./buildkite/scripts/export-git-env-vars.sh

# Download required debians from bucket locally
if [ -z "$DEBS" ]; then 
    echo "DEBS env var is empty. It should contains comma delimitered names of debians to install"
    exit -1
else
  debs=(${DEBS//,/ })
  for i in "${debs[@]}"; do
    case $i in
      mina-berkeley|mina-devnet|mina-mainnet)
        # Downaload mina-logproc too
        source ./buildkite/scripts/download-artifact-from-cache.sh "mina-logproc*" $MINA_DEB_CODENAME/_build "" "_build"
      ;;
      mina-create-legacy-genesis)
        # Download locally static debians (for example mina-legacy-create-genesis )
        gsutil -m cp "gs://buildkite_k8s/coda/shared/debs/$i*" $LOCAL_DEB_FOLDER
      ;;
    esac
    source ./buildkite/scripts/download-artifact-from-cache.sh "${i}_*" $MINA_DEB_CODENAME/_build "" "_build"
  done
fi

# Start aptly
source ./scripts/debian/aptly.sh start --codename $MINA_DEB_CODENAME --debians _build --component unstable --clean --background

# Install debians
echo "Installing mina packages: $DEBS"
echo "deb [trusted=yes] http://localhost:8080 $MINA_DEB_CODENAME unstable" | sudo tee /etc/apt/sources.list.d/mina.list
sudo apt-get update --yes
sudo apt-get install --yes --allow-downgrades "${arr_of_debs[@]}"


# Cleaning up
source ./scripts/debian/aptly.sh stop  --clean
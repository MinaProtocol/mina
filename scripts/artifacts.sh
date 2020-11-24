#!/bin/bash

# script for copying artifacts out to GC

set -ef -o pipefail

# Identify CI
if [[ ! "$CIRCLE_BUILD_NUM" ]]; then
    echo "Not running in CI, stopping."
    exit 0
fi

# No creds
if [[ -z "$JSON_GCLOUD_CREDENTIALS" || "$JSON_GCLOUD_CREDENTIALS" == "" ]]; then
    echo "Skipping artifact upload as creds are missing"
    exit 0
fi

do_copy () {

    # GC and credentials
    set +e
    path_to_gcloud=$(which gcloud)
    if [ -x "$path_to_gcloud" ] ; then
        echo "Found gcloud: $path_to_glcoud"
    else
        export HOMEBREW_NO_AUTO_UPDATE=1
        # Version in brew is currently broken, see https://github.com/GoogleCloudPlatform/gsutil/issues/1052
        # brew cask install google-cloud-sdk
        # source "/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc"
        # Get the tarball of the most recent working OS X version
        curl --output gcloud-sdk.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-297.0.1-darwin-x86_64.tar.gz
        tar -xz -f gcloud-sdk.tar.gz
        pushd google-cloud-sdk
        chmod +x install.sh
        ./install.sh --rc-path $PWD/gcloud-rc.sh --path-update true --quiet
        source $PWD/gcloud-rc.sh
        popd
    fi
    set -e

    echo $JSON_GCLOUD_CREDENTIALS > google_creds.json
    gcloud auth activate-service-account --key-file=google_creds.json

    SOURCES="/tmp/artifacts/* package/*"
    DESTINATION="gs://network-debug/${CIRCLE_BUILD_NUM}/build/"

    for SOURCE in $SOURCES
    do
        set +e
        echo "Copying ${SOURCE} to ${DESTINATION}"
        gsutil -o GSUtil:parallel_composite_upload_threshold=100M -q cp ${SOURCE} ${DESTINATION}
        gsutil ls ${DESTINATION}
        set -e
    done
}

case $CIRCLE_JOB in
    "build-artifacts--testnet_postake_medium_curves") do_copy;;
    "build-artifacts--testnet_postake_many_producers_medium_curves") do_copy;;
    "build-macos") do_copy;;
    "build-artifacts-optimized--testnet_postake_medium_curves") do_copy;;
    *) echo "Not an active testnet job (${CIRCLE_JOB}), stopping." ; exit 0 ;;
esac

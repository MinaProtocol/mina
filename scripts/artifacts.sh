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
    # GC credentials
    echo $JSON_GCLOUD_CREDENTIALS > google_creds.json
    /usr/bin/gcloud auth activate-service-account --key-file=google_creds.json

    SOURCES="/tmp/artifacts/*"
    DESTINATION="gs://network-debug/${CIRCLE_BUILD_NUM}/build/"

    for SOURCE in $SOURCES
    do
        echo "Copying ${SOURCE} to ${DESTINATION}"
        gsutil -o GSUtil:parallel_composite_upload_threshold=100M -q cp ${SOURCE} ${DESTINATION}
        gsutil ls ${DESTINATION}
    done
}

case $CIRCLE_JOB in
  "build-artifacts--testnet_postake" | "build-artifacts--testnet_postake_snarkless_fake_hash" | "build-artifacts--testnet_postake_medium_curves" |  "build-artifacts--testnet_postake_many_proposers_medium_curves") do_copy;;
   *) echo "Not an active testnet job (${CIRCLE_JOB}), stopping." ; exit 0 ;;
esac

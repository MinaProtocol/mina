#!/bin/bash

# script for copying artifacts out to GC

set -ef -o pipefail

# Identify CI
if [[ ! "$CIRCLE_BUILD_NUM" ]]; then
    echo "Not running in CI, stopping."
    exit 0
fi

do_copy () {
    SOURCES="/tmp/artifacts/buildocaml.log src/_build/default/lib/coda_base/sample_keypairs.ml /tmp/artifacts/coda.deb"
    DESTINATION="gs://network-debug/${CIRCLE_BUILD_NUM}/build/"

    for SOURCE in $SOURCES
    do
        echo "Copying ${SOURCE} to ${DESTINATION}"
        gsutil cp ${SOURCE} ${DESTINATION}
    done
}

case $CIRCLE_JOB in
  "build_testnet_postake" | "build_testnet_postake_snarkless_fake_hash") do_copy;;
   *) echo "Not an active testnet job, stopping." ; exit 0 ;;
esac


#!/bin/bash
set -euxo pipefail

if [[ $CIRCLE_BRANCH == 'master' ]]; then

    # GC credentials
    echo $JSON_GCLOUD_CREDENTIALS > google_creds.json
    /usr/bin/gcloud auth activate-service-account --key-file=google_creds.json
    /usr/bin/gcloud config set project $(cat google_creds.json | jq -r .project_id)

    # Get cached keys
    PINNED_KEY_COMMIT=temporary_hack
    /usr/bin/gsutil cp gs://proving-keys-stable/keys-$PINNED_KEY_COMMIT.tar.bz2 /tmp/.

    # Unpack keys
    sudo mkdir -p /var/lib/coda
    cd /var/lib/coda
    sudo tar --strip-components=2 -xvf /tmp/keys-$PINNED_KEY_COMMIT.tar.bz2
    rm /tmp/keys-$PINNED_KEY_COMMIT.tar.bz2
fi

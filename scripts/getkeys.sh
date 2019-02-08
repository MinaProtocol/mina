#!/bin/bash
set -euxo pipefail

if [[ $CIRCLE_BRANCH == 'master' ]]; then

    # GC credentials
    set +x
    echo $JSON_GCLOUD_CREDENTIALS > google_creds.json
    set -x
    /usr/bin/gcloud auth activate-service-account --key-file=google_creds.json
    /usr/bin/gcloud config set project $(cat google_creds.json | jq -r .project_id)

    # Get cached keys
    PINNED_KEY_COMMIT=temporary_hack
    TARBALL="keys-${PINNED_KEY_COMMIT}-${DUNE_PROFILE}.tar.bz2"
    /usr/bin/gsutil cp gs://proving-keys-stable/$TARBALL /tmp/.

    # Unpack keys
    sudo mkdir -p /var/lib/coda
    cd /var/lib/coda
    sudo tar --strip-components=2 -xvf /tmp/$TARBALL
    rm /tmp/$TARBALL
fi

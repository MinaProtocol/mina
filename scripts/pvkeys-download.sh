#!/bin/bash

# Downloads a stable set of PV keys.

set -eo pipefail

# When running in CI
if [ "$CI" = true ] ; then
    # Get fixed set of PV keys (which needs to be updated when snark changes)
    if [ -z "$JSON_GCLOUD_CREDENTIALS" ]; then
        echo "WARNING: JSON_GCLOUD_CREDENTIALS not set, static PV keys not used"
        exit 0
    fi

    # GC credentials
    echo $JSON_GCLOUD_CREDENTIALS > google_creds.json
    /usr/bin/gcloud auth activate-service-account --key-file=google_creds.json
fi

# Debug output
#set -x

# Get cached keys
echo "------------------------------------------------------------"
echo "Downloading keys"

set +e

# Look for tar based on branch name
if gsutil -q stat gs://proving-keys-stable/keys-${CIRCLE_BRANCH}-${DUNE_PROFILE}.tar.bz2
then
    TARBALL="keys-${CIRCLE_BRANCH}-${DUNE_PROFILE}.tar.bz2"
# Fall back to old tar based on just DUNE_PROFILE
elif gsutil -q stat gs://proving-keys-stable/keys-temporary_hack-${DUNE_PROFILE}.tar.bz2
then
    TARBALL="keys-temporary_hack-${DUNE_PROFILE}.tar.bz2"
else
    echo "PV Archive not found - Skipping"
    exit 0
fi

echo "Found ${TARBALL}"

URI="gs://proving-keys-stable/${TARBALL}"
gsutil cp ${URI} /tmp/.

# Unpack keys
echo "------------------------------------------------------------"
echo "Unapacking keys"
sudo mkdir -p /var/lib/coda
cd /var/lib/coda
#sudo tar --strip-components=2 -xvf /tmp/$TARBALL
sudo tar -xvf /tmp/$TARBALL
rm /tmp/$TARBALL

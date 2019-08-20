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

# Derive branch being merged in to
# Usually a fix/feature branch PR won't have PV keys
PR_NUMBER=`basename ${CIRCLE_PULL_REQUEST:-NOPR}`
GH_API="https://api.github.com/repos/CodaProtocol/coda/pulls"
MERGE_INTO_BRANCH=`curl -s ${GH_API}/${PR_NUMBER} | jq -r .base.ref`
CIRCLE_BRANCH_NOSLASH=$( echo ${CIRCLE_BRANCH} |  sed 's!/!-!; s!!-!g' )
MERGE_INTO_BRANCH_NOSLASH=$( echo ${MERGE_INTO_BRANCH} |  sed 's!/!-!; s!!-!g' )

# Iterate over a few name variations until you a match?
NAME_VARIATIONS="
keys-${CIRCLE_BRANCH_NOSLASH:-NOBRANCH_NOSLASH}-${DUNE_PROFILE:-NOPROFILE}.tar.bz2
keys-${CIRCLE_BRANCH:-NOBRANCH}-${DUNE_PROFILE:-NOPROFILE}.tar.bz2
keys-${MERGE_INTO_BRANCH_NOSLASH:-NOBRANCH_NOSLASH}-${DUNE_PROFILE:-NOPROFILE}.tar.bz2
keys-${MERGE_INTO_BRANCH:-NOBRANCH}-${DUNE_PROFILE:-NOPROFILE}.tar.bz2
keys-temporary_hack-${DUNE_PROFILE:-NOPROFILE}.tar.bz2
NOTFOUND
"

for TARBALL in ${NAME_VARIATIONS}
do
    echo "Checking for ${TARBALL}"
    if gsutil -q stat gs://proving-keys-stable/$TARBALL
    then
        # Found a file matching this name, keep it
        break
    fi
done

if [[ $TARBALL = "NOTFOUND" ]]; then
    echo "No usable PV tarball found"
    exit 0
fi

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

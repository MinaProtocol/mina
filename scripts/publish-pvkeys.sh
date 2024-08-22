#!/bin/bash
set -eo pipefail

KEYDIR="/tmp/coda_cache_dir/"

# Only publish if we have AWS Creds
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "WARNING: AWS_ACCESS_KEY_ID not set, publish commands not run"
else
    # Only publish if there are generated files in place.
    shopt -s nullglob dotglob  # check for empty or dotfiles
    genfiles=("${KEYDIR}"*)
    if [ ${#genfiles[@]} -gt 0 ]; then
        ls -l ${KEYDIR}
        aws s3 sync --acl public-read ${KEYDIR} s3://snark-keys-ro.o1test.net/
    else
        echo "No build time generated keys found."
    fi
fi

#!/bin/bash

GENESIS_DIR="/tmp/coda_cache_dir/"

# Need AWS creds to upload
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "WARNING: AWS_ACCESS_KEY_ID is missing, not uploading files for genesis"
else
    if ls -l ${GENESIS_DIR}genesis_*; then
        aws s3 sync --exclude "*" --include "genesis_*" --acl public-read ${GENESIS_DIR} s3://snark-keys.o1test.net/
    fi
fi

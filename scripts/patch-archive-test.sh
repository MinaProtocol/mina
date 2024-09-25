#!/bin/bash

set -x
# test replayer on known archive db

NETWORK_DATA_FOLDER=src/test/archive/sample_db
PATCH_ARCHIVE_TEST_APP=${PATCH_ARCHIVE_TEST_APP:-_build/default/src/test/archive/patch_archive_test/patch_archive_test.exe}
PG_PORT=${PG_PORT:-5432}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}

CONN=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${PG_PORT}


echo "Running patch archive test"
$PATCH_ARCHIVE_TEST_APP --source-uri $CONN \
                        --network-data-folder $NETWORK_DATA_FOLDER

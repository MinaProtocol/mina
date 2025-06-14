#!/bin/bash

set -x
# test replayer on known archive db

NETWORK_DATA_FOLDER=src/test/archive/sample_db
PATCH_ARCHIVE_TEST_APP=${PATCH_ARCHIVE_TEST_APP:-_build/default/src/test/archive/patch_archive_test/patch_archive_test.exe}
PG_PORT=${PG_PORT:-5433}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}

CONN=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${PG_PORT}

# Build the directory and the archive_db alias to download the SQL file
# Note: In CI, the SQL file is already downloaded by RunWithPostgres.dhall
# but we keep this here for local development
if [ ! -f "_build/default/${NETWORK_DATA_FOLDER}/archive_db.sql" ]; then
  dune b "${NETWORK_DATA_FOLDER}"
  dune b @"${NETWORK_DATA_FOLDER}/archive_db"
fi


echo "Running patch archive test"
"${PATCH_ARCHIVE_TEST_APP}" --source-uri "${CONN}" \
                            --network-data-folder "_build/default/${NETWORK_DATA_FOLDER}"

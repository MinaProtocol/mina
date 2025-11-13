#!/bin/bash

set -eoux pipefail
# test convert canonical blocks on known archive db

CONVERT_CANONICAL_BLOCKS_TEST_APP=${CONVERT_CANONICAL_BLOCKS_TEST_APP:-_build/default/src/app/archive_hardfork_toolbox/tests/test_convert_canonical.exe}
PG_PORT=${PG_PORT:-5433}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}

CONN=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${PG_PORT}


echo "Running convert canonical blocks test"
"${CONVERT_CANONICAL_BLOCKS_TEST_APP}" --postgres-uri "${CONN}"
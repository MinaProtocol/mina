#!/bin/bash

set -eoux pipefail
# test convert canonical blocks on known archive db

PG_PORT=${PG_PORT:-5433}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}

CONN=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${PG_PORT}

source ~/.profile

echo "Running convert canonical blocks test"
POSTGRES_URI="${CONN}" dune runtest src/app/archive_hardfork_toolbox/tests
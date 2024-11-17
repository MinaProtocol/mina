#!/bin/bash

set -x
# test archive node on known archive db

NETWORK_DATA_FOLDER=${NETWORK_DATA_FOLDER:-src/test/archive/sample_db}
ARCHIVE_TEST_APP=${ARCHIVE_TEST_APP:-_build/default/src/test/archive/archive_node_tests/archive_node_tests.exe}
POSTGRES_URI=${POSTGRES_URI:-"postgres://postgres:postgres@localhost:5432"}

echo "Running archive node test"
$ARCHIVE_TEST_APP

#!/bin/bash

set -x

buildkite/scripts/debian/update.sh --verbose

apt-get install -y procps

# test archive node on known archive db
NETWORK_DATA_FOLDER=${NETWORK_DATA_FOLDER:-src/test/archive/sample_db}
ARCHIVE_TEST_APP=${ARCHIVE_TEST_APP:-_build/default/src/test/archive/archive_node_tests/archive_node_tests.exe}

# This env var is used in the test app
# shellcheck disable=SC2034
MINA_TEST_POSTGRES_URI=${POSTGRES_URI:-"postgres://postgres:postgres@localhost:5432"}

echo "Running archive node test"
echo "WARN: Silencing the errors from the archive node test app. One of the tests is expected to fail."
MINA_TEST_POSTGRES_URI=$MINA_TEST_POSTGRES_URI $ARCHIVE_TEST_APP -v
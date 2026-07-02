#!/bin/bash

set -x

buildkite/scripts/debian/update.sh --verbose

# test archive node on known archive db
NETWORK_DATA_FOLDER=${NETWORK_DATA_FOLDER:-src/test/archive/sample_db}
ARCHIVE_TEST_APP=${ARCHIVE_TEST_APP:-_build/default/src/test/archive/archive_node_tests/archive_node_tests.exe}

# This env var is used in the test app
# shellcheck disable=SC2034
MINA_TEST_POSTGRES_URI=${POSTGRES_URI:-"postgres://postgres:postgres@localhost:5432"}

# Collect the test log here so Buildkite can upload it as an artifact
# (see artifact_paths in buildkite/src/Command/ArchiveNodeTest.dhall).
# Running with -v makes Alcotest stream the full per-test output (including the
# exception/backtrace the summary collapses to "exception") to stdout, which the
# tee below captures, so we don't need to also ship Alcotest's _build/_tests
# tree (whose suite-named subdirectories break the artifact glob).
ARTIFACTS_DIR=${ARTIFACTS_DIR:-test_output/artifacts}
mkdir -p "$ARTIFACTS_DIR"
TEST_LOG="$ARTIFACTS_DIR/archive-node-test.log"

echo "Running archive node test"
# pipefail so the test's exit status survives the tee pipe; tee keeps the
# output on the console while also persisting it to the uploaded artifact.
set -o pipefail
MINA_TEST_POSTGRES_URI=$MINA_TEST_POSTGRES_URI $ARCHIVE_TEST_APP -v 2>&1 | tee "$TEST_LOG"
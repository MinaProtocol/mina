#!/bin/bash

set -x

buildkite/scripts/debian/update.sh --verbose

# test archive node on known archive db
NETWORK_DATA_FOLDER=${NETWORK_DATA_FOLDER:-src/test/archive/sample_db}
ARCHIVE_TEST_APP=${ARCHIVE_TEST_APP:-_build/default/src/test/archive/archive_node_tests/archive_node_tests.exe}

# This env var is used in the test app
# shellcheck disable=SC2034
MINA_TEST_POSTGRES_URI=${POSTGRES_URI:-"postgres://postgres:postgres@localhost:5432"}

# Collect test logs here so Buildkite can upload them as artifacts
# (see artifact_paths in buildkite/src/Command/ArchiveNodeTest.dhall).
ARTIFACTS_DIR=${ARTIFACTS_DIR:-test_output/artifacts}
mkdir -p "$ARTIFACTS_DIR"
TEST_LOG="$ARTIFACTS_DIR/archive-node-test.log"

# On exit, also gather Alcotest's per-test output (contains the full
# exception/backtrace that the console summary collapses to "exception").
collect_alcotest_logs () {
  if [[ -d _build/_tests ]]; then
    cp -r _build/_tests "$ARTIFACTS_DIR/alcotest" 2>/dev/null || true
  fi
}
trap collect_alcotest_logs EXIT

echo "Running archive node test"
# pipefail so the test's exit status survives the tee pipe; tee keeps the
# output on the console while also persisting it to the uploaded artifact.
set -o pipefail
MINA_TEST_POSTGRES_URI=$MINA_TEST_POSTGRES_URI $ARCHIVE_TEST_APP -v 2>&1 | tee "$TEST_LOG"
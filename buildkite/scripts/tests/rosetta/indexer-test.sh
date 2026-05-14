#!/bin/bash
set -eox pipefail

# Install mina-rosetta debs onto the host so mina-rosetta-indexer-test is
# available without needing the prebuilt mina-rosetta docker image.
source ./buildkite/scripts/tests/rosetta/install-debs.sh

mina-rosetta-indexer-test --archive_uri "$PG_CONN"

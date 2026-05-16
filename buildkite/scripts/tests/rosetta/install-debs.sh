#!/bin/bash

# Installs the debian packages needed by the rosetta integration / indexer
# tests on the host where the test script is running. Replaces the previous
# pattern of running the tests inside the prebuilt mina-rosetta docker image.
#
# Pulls the freshly-built debs out of the buildkite cache (per
# buildkite/scripts/debian/install.sh), installs them via aptly, then drops
# the local repo. Idempotent: invoke from the top of any rosetta test script.
#
# Required env: MINA_DEB_CODENAME, BUILDKITE_BUILD_ID, MINA_NETWORK_DEB
#   (network suffix that matches the rosetta deb, e.g. "devnet" -> mina-rosetta-devnet)

set -eo pipefail

NETWORK="${MINA_NETWORK_DEB:-devnet}"

DEBS=(
  "mina-${NETWORK}"
  "mina-archive-${NETWORK}"
  "mina-rosetta-${NETWORK}"
  "mina-zkapp-test-transaction"
)

DEBS_CSV="$(IFS=,; echo "${DEBS[*]}")"

# Use sudo (toolchain image runs as opam user with NOPASSWD sudo).
source ./buildkite/scripts/debian/install.sh "${DEBS_CSV}" 1

# The mina-${NETWORK} deb ships /var/lib/coda/config_<commit>.json which the
# daemon auto-loads on startup and merges with --config-file. For devnet that
# config carries an `epoch_data` block pointing at a published epoch ledger
# tarball that isn't present on disk here, causing the daemon to crash with
# "Could not find a ledger tar file for hash 'jxvdSn...'". The rosetta
# integration test supplies its own complete runtime config via --config-file,
# so the auto-picked one is pure overhead — drop it.
sudo rm -f /var/lib/coda/config_*.json

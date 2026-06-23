#!/bin/bash

# Installs the debian packages needed by the rosetta integration / indexer
# tests on the host where the test script is running. Replaces the previous
# pattern of running the tests inside the prebuilt mina-rosetta docker image.
#
# Pulls the freshly-built debs out of the buildkite cache (per
# buildkite/scripts/debian/install.sh) and installs them directly as local
# .deb files via apt-get. Idempotent: invoke from the top of any rosetta test
# script.
#
# Required env: MINA_DEB_CODENAME, BUILDKITE_BUILD_ID, MINA_NETWORK_DEB
#   (network suffix that matches the rosetta deb, e.g. "devnet" -> mina-rosetta-devnet)

set -eo pipefail

NETWORK="${MINA_NETWORK_DEB:-devnet}"

# Use the *-generic daemon package instead of mina-${NETWORK}. Same daemon
# binaries (mina client/daemon/libp2p) but no dependency on
# mina-${NETWORK}-config, so no /var/lib/coda/config_<commit>.json gets
# installed. Without that file the daemon doesn't auto-merge the published
# devnet runtime config (which carries epoch_data for an epoch ledger we
# don't ship) on top of our --config-file, and starts cleanly against the
# test's hand-rolled testnet.json.
DEBS=(
  "mina-generic"
  "mina-archive-${NETWORK}"
  "mina-rosetta-${NETWORK}"
  "mina-tx-tools"
)

DEBS_CSV="$(IFS=,; echo "${DEBS[*]}")"

# Run the installer in a child process (not `source`d) so its strict-mode
# flags (`set -u`, custom `PS4`) don't leak back into the calling shell. Use
# sudo (toolchain image runs as opam user with NOPASSWD sudo).
#
# restore-or-install.sh is a drop-in for debian/install.sh: when
# APPS_BARE_BINARIES is set it restores the freshly dune-built executables from
# the apps cache (skipping the deb install, so no prebuilt mina-rosetta docker
# image / published debs are needed); when it is unset (or a cache miss occurs)
# it falls back to installing the debs above, preserving the previous behaviour.
bash ./buildkite/scripts/debian/restore-or-install.sh "${DEBS_CSV}" 1

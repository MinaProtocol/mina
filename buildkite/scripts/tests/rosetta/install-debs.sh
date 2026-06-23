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
  "mina-${NETWORK}-generic"
  "mina-archive-${NETWORK}"
  "mina-rosetta-${NETWORK}"
  "mina-zkapp-test-transaction"
)

DEBS_CSV="$(IFS=,; echo "${DEBS[*]}")"

# Prefer bare binaries from the apps cache (mirroring exactly what the debs
# above install) and fall back to the .deb install on any cache miss, via
# restore-or-install.sh. The signature flavor follows the network: devnet uses
# the testnet signatures, mainnet the mainnet ones. Cached names are the
# flattened *.exe basenames written by buildkite/scripts/apps/write_to_cache.sh
# (e.g. ocaml-signer/signer_testnet_signatures.exe is cached as its basename).
# rosetta-cli is built separately by install-cli.sh; the non-binary payload the
# rosetta deb ships under /etc/mina/rosetta (rosetta-cli-config, postgresql.conf)
# is read from the in-repo copies by integration-tests.sh in the bare path.
case "${NETWORK}" in
  mainnet) SIG=mainnet ;;
  *)       SIG=testnet ;;
esac
export APPS_NETWORK="${NETWORK}"
export APPS_BARE_BINARIES="mina_${SIG}_signatures.exe:mina,libp2p_helper:coda-libp2p_helper,archive.exe:mina-archive,rosetta_${SIG}_signatures.exe:mina-rosetta,signer_${SIG}_signatures.exe:mina-ocaml-signer,indexer_test.exe:mina-rosetta-indexer-test,zkapp_test_transaction.exe:mina-zkapp-test-transaction"

# Run in a child process (not `source`d) so its strict-mode flags (`set -u`,
# custom `PS4`) don't leak back into the calling shell. Use sudo (toolchain
# image runs as opam user with NOPASSWD sudo).
bash ./buildkite/scripts/debian/restore-or-install.sh "${DEBS_CSV}" 1

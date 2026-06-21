#!/bin/bash

# Reproduce the daemon *config* package's payload for a network from the in-repo
# genesis ledger, so callers get the same /var/lib/coda layout a .deb provides
# without installing one. This is the config-side companion to restore_binary.sh
# (which restores the daemon binary from the apps cache): together they let a
# test run on the freshly-built binary + repo data instead of the package.
#
# Usage: restore_daemon_config.sh <network>      (network: devnet | mainnet | mesa)
#
# Mirrors copy_common_daemon_configs in scripts/debian/builder-helpers.sh: the
# config package does no generation -- it just copies the in-repo
# genesis_ledgers/<network>.json into /var/lib/coda as both
#   - config_<GITHASH_CONFIG>.json  (the "magic" config the daemon auto-loads), and
#   - <network>.json                (the named config passed via --config-file).
# We copy the very same file to the very same paths, so the daemon resolves the
# genesis ledger identically to the packaged case.
#
# GITHASH_CONFIG comes from buildkite/scripts/export-git-env-vars.sh; if it is
# unset we still lay down the named config (the magic config is best-effort).
# Target dir is ${MINA_CONFIG_DIR:-/var/lib/coda}; uses sudo when not root.

set -eo pipefail

NETWORK=$1

if [[ -z "$NETWORK" ]]; then
  echo "Usage: $0 <network>" >&2
  exit 1
fi

case "$NETWORK" in
  devnet | mainnet | mesa) ;;
  *)
    echo "restore_daemon_config: unknown network '$NETWORK'" >&2
    exit 1
    ;;
esac

SRC="genesis_ledgers/${NETWORK}.json"
if [[ ! -f "$SRC" ]]; then
  echo "restore_daemon_config: ${SRC} not found" >&2
  exit 1
fi

CODA_DIR="${MINA_CONFIG_DIR:-/var/lib/coda}"

SUDO=""
if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

$SUDO mkdir -p "$CODA_DIR"
$SUDO cp "$SRC" "${CODA_DIR}/${NETWORK}.json"

if [[ -n "${GITHASH_CONFIG:-}" ]]; then
  $SUDO cp "$SRC" "${CODA_DIR}/config_${GITHASH_CONFIG}.json"
else
  echo "restore_daemon_config: GITHASH_CONFIG unset, skipping magic config" >&2
fi

echo "restore_daemon_config: installed ${NETWORK} genesis config into ${CODA_DIR}" >&2

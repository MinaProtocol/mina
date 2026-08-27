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
# The magic config is named after the build's git hash. We resolve it the same
# way the deb build does (scripts/export-git-env-vars.sh): use GITHASH_CONFIG if
# already exported (callers normally `source export-git-env-vars.sh` first), else
# an explicit OVERRIDE_GITHASH, else derive it from HEAD -- so the hash is always
# determined, never skipped. Target dir is ${MINA_CONFIG_DIR:-/var/lib/coda};
# uses sudo when not root.

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

# Resolve the build git hash exactly as export-git-env-vars.sh does, falling
# back to HEAD so it is always defined (not best-effort).
GITHASH_CONFIG="${GITHASH_CONFIG:-${OVERRIDE_GITHASH:-$(git rev-parse --short=8 --verify HEAD 2>/dev/null || true)}}"

if [[ -z "$GITHASH_CONFIG" ]]; then
  echo "restore_daemon_config: could not determine GITHASH_CONFIG (set GITHASH_CONFIG/OVERRIDE_GITHASH, or run inside a git checkout)" >&2
  exit 1
fi

$SUDO mkdir -p "$CODA_DIR"
$SUDO cp "$SRC" "${CODA_DIR}/${NETWORK}.json"
$SUDO cp "$SRC" "${CODA_DIR}/config_${GITHASH_CONFIG}.json"

echo "restore_daemon_config: installed ${NETWORK} genesis config (incl. config_${GITHASH_CONFIG}.json) into ${CODA_DIR}" >&2

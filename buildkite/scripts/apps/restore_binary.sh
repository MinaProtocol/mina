#!/bin/bash

# Restore the freshly-built mina daemon binary for a network from the namespaced
# apps CI cache (written by buildkite/scripts/apps/write_to_cache.sh) and install
# it as `mina` on PATH -- mirroring the .deb -- so callers invoke `mina`
# identically whether it came from the cache or a package.
#
# Usage: restore_binary.sh <network>      (network: devnet | mainnet | mesa)
#
# This is a thin convenience wrapper over restore_app.sh: it installs the daemon
# binary as the plain `mina`, so client scripts never deal with the variant. The
# app-build (and the .deb, see scripts/debian/builder-helpers.sh) ships
# src/app/cli/src/mina.exe as `mina`; the network's signatures are baked in at
# build time via the profile and encoded in the cache variant that restore_app.sh
# derives from the network -- there is no separate mina_<sig>_signatures.exe in
# the cache. The cache location (codename/profile/flag/arch) is derived from the
# build identity by restore_app.sh -- see its header for the env knobs.
#
# Exits non-zero without side effects if not in Buildkite context or the binary
# is not cached, so callers can fall back to installing the .deb.

set -eo pipefail

NETWORK=$1

if [[ -z "$NETWORK" ]]; then
  echo "Usage: $0 <network>" >&2
  exit 1
fi

case "$NETWORK" in
  devnet | mesa | mainnet) ;;
  *)
    echo "restore_binary: unknown network '$NETWORK'" >&2
    exit 1
    ;;
esac

exec ./buildkite/scripts/apps/restore_app.sh "$NETWORK" mina.exe mina

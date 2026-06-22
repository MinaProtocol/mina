#!/bin/bash

# Drop-in alternative to debian/install.sh for tests that can run from bare
# cached binaries instead of installing the package.
#
# Usage: restore-or-install.sh <comma-separated-debs> <retries>
#
# Opt-in via APPS_BARE_BINARIES: a comma-separated list of <cached-exe>:<install-as>
# pairs (e.g. "archive.exe:mina-archive,replayer.exe:mina-replayer"). When set,
# each binary is restored from the namespaced apps cache (mirroring the binary a
# deb would install) via restore_app.sh, and the package install is skipped. The
# cache variant is derived by restore_app.sh from MINA_DEB_CODENAME / APPS_PROFILE
# / APPS_BUILD_FLAG / APPS_ARCH -- so callers set those to match the build they
# depend on (e.g. APPS_BUILD_FLAG=instrumented).
#
# If APPS_BARE_BINARIES is unset, or any restore fails (cache miss, not in
# Buildkite, ...), this falls back to `debian/install.sh <debs> <retries>` -- so
# it is a behaviour-preserving no-op for any caller that has not opted in.
#
# Some debs ship "binaries" that are actually in-repo shell scripts (e.g. the
# missing-blocks guardian). For those, set APPS_BARE_SCRIPTS: a comma-separated
# list of <repo-path>:<install-as> pairs. When the bare restore is taken, each
# script is installed onto PATH as /usr/local/bin/<install-as>, mirroring the deb.
#
# Note: this only provisions the binaries/scripts. Non-binary payload a deb would
# supply (genesis config, fixtures, SQL) must be reproduced by the test from
# in-repo data; converted tests are expected to point at the in-repo copies.

set -eo pipefail

DEBS=$1
RETRIES=${2:-1}
NETWORK="${APPS_NETWORK:-devnet}"

if [[ -z "$DEBS" ]]; then
  echo "Usage: $0 <comma-separated-debs> <retries>" >&2
  exit 1
fi

install_debs() {
  ./buildkite/scripts/debian/install.sh "$DEBS" "$RETRIES"
}

if [[ -z "${APPS_BARE_BINARIES:-}" ]]; then
  install_debs
  exit $?
fi

SUDO=""
if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi
BIN_DIR="${MINA_BIN_DIR:-/usr/local/bin}"

ok=true
IFS=',' read -ra pairs <<< "$APPS_BARE_BINARIES"
for pair in "${pairs[@]}"; do
  exe="${pair%%:*}"
  install_as="${pair##*:}"
  if [[ -z "$exe" || -z "$install_as" || "$exe" == "$pair" ]]; then
    echo "restore-or-install: malformed APPS_BARE_BINARIES entry '$pair'" >&2
    ok=false
    break
  fi
  if ! ./buildkite/scripts/apps/restore_app.sh "$NETWORK" "$exe" "$install_as"; then
    ok=false
    break
  fi
done

# In-repo scripts the deb would install as binaries (e.g. the guardian).
if $ok && [[ -n "${APPS_BARE_SCRIPTS:-}" ]]; then
  IFS=',' read -ra scripts <<< "$APPS_BARE_SCRIPTS"
  for s in "${scripts[@]}"; do
    src="${s%%:*}"
    install_as="${s##*:}"
    if [[ -z "$src" || -z "$install_as" || "$src" == "$s" || ! -f "$src" ]]; then
      echo "restore-or-install: missing/malformed APPS_BARE_SCRIPTS entry '$s'" >&2
      ok=false
      break
    fi
    $SUDO install -D -m 0755 "$src" "${BIN_DIR}/${install_as}"
    echo "restore-or-install: installed script ${src} as ${BIN_DIR}/${install_as}" >&2
  done
fi

if $ok; then
  echo "restore-or-install: restored [${APPS_BARE_BINARIES}] from apps cache; skipping deb install" >&2
else
  echo "restore-or-install: bare restore incomplete, falling back to debian install of [${DEBS}]" >&2
  install_debs
fi

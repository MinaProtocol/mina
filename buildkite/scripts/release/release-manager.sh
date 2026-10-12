#!/bin/bash

# Run mina-release-toolkit's release-manager on the agent host.
#
# Host, not the toolkit image: `release-manager docker` drives the host docker
# daemon, its registry logins, and host paths for -v mounts. The release .deb
# ships a static binary, so it runs on any agent.
#
# Usage: RELEASE_TOOLKIT_VERSION=<x.y.z> release-manager.sh <args...>

set -euo pipefail

VERSION="${RELEASE_TOOLKIT_VERSION:?RELEASE_TOOLKIT_VERSION is not set}"
DIR="${TMPDIR:-/tmp}/mina-release-toolkit-${VERSION}"
BIN="${DIR}/release-manager"

if [[ ! -x "${BIN}" ]]; then
  mkdir -p "${DIR}"
  WORK=$(mktemp -d "${DIR}/.fetch.XXXXXX")
  curl -fsSL --retry 3 -o "${WORK}/toolkit.deb" \
    "https://github.com/MinaProtocol/mina-release-toolkit/releases/download/v${VERSION}/mina-release-toolkit_${VERSION}_amd64.deb"
  dpkg-deb -x "${WORK}/toolkit.deb" "${WORK}/root"
  # Same filesystem, so concurrent jobs on one agent never see a partial file.
  mv -f "${WORK}/root/usr/bin/release-manager" "${BIN}"
  rm -rf "${WORK}"
fi

exec "${BIN}" "$@"

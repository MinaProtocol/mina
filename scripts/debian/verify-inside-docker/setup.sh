#!/usr/bin/env bash
# Common setup: add repo, install package. Sourced by per-package verify scripts.
set -euo pipefail
set -x

export DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC

PACKAGE="$1"
VERSION="$2"
REPO="$3"
CODENAME="$4"
CHANNEL="$5"
SIGNED="${6:-0}"
TRUSTED_FLAG="${7:-[trusted=yes]}"

echo "Installing $PACKAGE=$VERSION from $REPO ($CODENAME/$CHANNEL)"

apt-get update
apt-get install -y lsb-release ca-certificates wget gnupg

if [[ "$SIGNED" == "1" ]]; then
  wget -q "https://${REPO}/repo-signing-key.gpg" -O /etc/apt/trusted.gpg.d/minaprotocol.gpg
  TRUSTED_FLAG=""
fi

echo "deb ${TRUSTED_FLAG} https://${REPO} ${CODENAME} ${CHANNEL}" > /etc/apt/sources.list.d/mina.list
apt-get update

apt list -a "$PACKAGE"
apt-get install -y --allow-downgrades "${PACKAGE}=${VERSION}"

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

# bullseye left LTS at the end of Aug 2026 and its security Release file is no
# longer re-signed, so apt rejects the stale metadata outright.  Drop only the
# freshness check, and only there; signatures are still verified.
if [[ "$CODENAME" == "bullseye" ]]; then
  echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-valid-until
fi

apt-get update

# ca-certificates alone is enough to fetch from an https repo with
# [trusted=yes]; wget/gnupg are only needed to import the signing key for
# signed repos.  Keep the installs separate: on EOL codenames (e.g. bullseye
# after Aug 2026) parts of the security pool 404, and one unrelated 404 in a
# shared apt transaction would take ca-certificates down with it.
apt-get install -y ca-certificates

if [[ "$SIGNED" == "1" ]]; then
  apt-get install -y wget gnupg
  wget -q "https://${REPO}/repo-signing-key.gpg" -O /etc/apt/trusted.gpg.d/minaprotocol.gpg
  TRUSTED_FLAG=""
fi

echo "deb ${TRUSTED_FLAG} https://${REPO} ${CODENAME} ${CHANNEL}" > /etc/apt/sources.list.d/mina.list
apt-get update

apt list -a "$PACKAGE"
apt-get install -y --allow-downgrades "${PACKAGE}=${VERSION}"

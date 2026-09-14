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

# Debian's official base images bake a commented-out snapshot.debian.org source
# pair into /etc/apt/sources.list, pinned at the date the image was built. Turn
# those on and comment the live deb.debian.org archive out.
#
# This is the recovery path for an end-of-life codename. When a Debian release
# leaves LTS the security pocket stops being re-signed and is then drained:
# bullseye left LTS on 2026-08-31, so
#   deb.debian.org/debian-security bullseye-security
# now serves a Release with a Valid-Until in the past and no packages behind it.
# Two failures follow, in this order:
#   1. apt-get update exits 100 with
#      "E: Release file for .../bullseye-security/InRelease is expired".
#   2. Even with the freshness check relaxed, the pocket is empty, so the only
#      gnupg left is the bullseye/main one, which cannot satisfy
#      "Depends: gpgv (< 2.2.27-2+deb11u2.1~)" against the gpgv 2.2.27-2+deb11u3
#      the image already carries from that same, now-drained pocket. The
#      bootstrap install then fails with "held broken packages", ca-certificates
#      is never installed, and the HTTPS mina repository added below is rejected
#      with "Certificate verification failed".
# The snapshot sources cure both at once: they are the exact archive state the
# image was built from, so gnupg 2.2.27-2+deb11u3 is there again. Their Release
# files are old by construction, hence [check-valid-until=no] - signatures are
# still verified, only the freshness check is skipped.
#
# archive.debian.org is NOT a substitute here: it carries the 11.11 point
# release (2024-08-31) and no debian-security pocket at all, so the gpgv
# version conflict above stays unresolved.
#
# Ubuntu base images ship no such pointer, so this is a no-op there and the
# caller falls through to the hard failure it would have had anyway.
use_debian_snapshot_sources() {
  grep -qs '^# deb .*snapshot\.debian\.org' /etc/apt/sources.list || return 1
  sed -i \
    -e 's|^# deb \(http://snapshot\.debian\.org/\)|deb [check-valid-until=no] \1|' \
    -e 's|^deb \(http://deb\.debian\.org/\)|# deb \1|' \
    /etc/apt/sources.list
  cat /etc/apt/sources.list
}

# Probe the distro's own sources rather than deciding from a hardcoded list of
# end-of-life codenames: the fallback then costs nothing while a codename is
# healthy and arms itself on the day that codename is drained.
if ! apt-get update; then
  echo "apt-get update failed against the distro archive; retrying with the base image's snapshot sources"
  use_debian_snapshot_sources || {
    echo "no snapshot.debian.org sources baked into this image; cannot recover"
    exit 1
  }
  apt-get update
fi

apt-get install -y lsb-release ca-certificates wget gnupg

if [[ "$SIGNED" == "1" ]]; then
  wget -q "https://${REPO}/repo-signing-key.gpg" -O /etc/apt/trusted.gpg.d/minaprotocol.gpg
  TRUSTED_FLAG=""
fi

echo "deb ${TRUSTED_FLAG} https://${REPO} ${CODENAME} ${CHANNEL}" > /etc/apt/sources.list.d/mina.list
apt-get update

apt list -a "$PACKAGE"
apt-get install -y --allow-downgrades "${PACKAGE}=${VERSION}"

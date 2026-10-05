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

# REPO may carry its own scheme. A bare host keeps the historical meaning and
# is served over HTTPS; an explicit http:// is used by the release-manager test
# suite, which serves a mock repository from a local MinIO container.
case "$REPO" in
  http://*|https://*) REPO_URL="$REPO" ;;
  *)                  REPO_URL="https://$REPO" ;;
esac

echo "Installing $PACKAGE=$VERSION from $REPO_URL ($CODENAME/$CHANNEL)"

# Work out what the base image is actually missing, rather than installing a
# fixed list. Every package here costs a round trip to the distribution
# archive, and that archive is the part most likely to be broken (see
# use_debian_snapshot_sources below), so asking for nothing we do not need
# removes the most common way this script fails.
#   - ca-certificates: only for an HTTPS repository. A plain HTTP mock needs no
#     trust store at all.
#   - wget: only to download the signing key of a signed repository.
#   - gnupg: only to let apt check that signature.
BOOTSTRAP_PACKAGES=()
case "$REPO_URL" in
  https://*)
    # Probe the trust bundle itself, which is what apt's TLS backend reads,
    # rather than the package name.
    [[ -s /etc/ssl/certs/ca-certificates.crt ]] || BOOTSTRAP_PACKAGES+=(ca-certificates)
    ;;
esac
if [[ "$SIGNED" == "1" ]]; then
  command -v wget > /dev/null 2>&1 || BOOTSTRAP_PACKAGES+=(wget)
  command -v gpgv > /dev/null 2>&1 || BOOTSTRAP_PACKAGES+=(gnupg)
fi

# Debian's official base images bake a commented-out snapshot.debian.org source
# pair into /etc/apt/sources.list, pinned at the date the image was built. Turn
# those on and comment the live deb.debian.org archive out.
#
# This is the recovery path for an end-of-life codename. When a Debian release
# leaves LTS the security pocket stops being re-signed and is then drained.
# bullseye left LTS on 2026-08-31, and the drain happens in two stages, which
# fail differently:
#   1. The Release file expires. apt-get update exits 100 with
#      "E: Release file for .../bullseye-security/InRelease is expired".
#   2. The Release file is refreshed but the pool behind it is emptied. Now
#      apt-get update SUCCEEDS and the failure moves to the download step:
#      "E: Failed to fetch .../gnupg_2.2.27-2+deb11u3_all.deb  404  Not Found".
#      apt then aborts the whole transaction, so nothing is unpacked - including
#      ca-certificates, even when its own .deb downloaded correctly. The HTTPS
#      repository added below is then rejected with "Certificate verification
#      failed", which is a confusing way to report a 404 somewhere else.
# Because of stage 2 the probe below has to cover the install, not just the
# update. Checking only apt-get update would leave the failure unhandled.
#
# The snapshot sources cure both stages at once: they are the exact archive
# state the image was built from, so every file the index promises is really
# there. Their Release files are old by construction, hence
# [check-valid-until=no] - signatures are still verified, only the freshness
# check is skipped.
#
# archive.debian.org is NOT a substitute here: it carries the 11.11 point
# release (2024-08-31) and no debian-security pocket at all, so the package
# versions the image already has installed stay unsatisfiable.
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

# Update the index and install the bootstrap packages as one unit, because
# either half can be the one that fails. Probe the distro's own archive rather
# than deciding from a hardcoded list of end-of-life codenames: the fallback
# then costs nothing while a codename is healthy and arms itself on the day
# that codename is drained.
bootstrap_from_distro_archive() {
  apt-get update || return 1
  if [[ ${#BOOTSTRAP_PACKAGES[@]} -gt 0 ]]; then
    apt-get install -y "${BOOTSTRAP_PACKAGES[@]}" || return 1
  fi
}

if [[ ${#BOOTSTRAP_PACKAGES[@]} -eq 0 ]]; then
  echo "Base image already has everything needed to read $REPO_URL; skipping the distribution archive"
elif ! bootstrap_from_distro_archive; then
  echo "Could not bootstrap from the distribution archive; retrying with the base image's snapshot sources"
  use_debian_snapshot_sources || {
    echo "no snapshot.debian.org sources baked into this image; cannot recover"
    exit 1
  }
  bootstrap_from_distro_archive
fi

if [[ "$SIGNED" == "1" ]]; then
  wget -q "${REPO_URL}/repo-signing-key.gpg" -O /etc/apt/trusted.gpg.d/minaprotocol.gpg
  TRUSTED_FLAG=""
fi

echo "deb ${TRUSTED_FLAG} ${REPO_URL} ${CODENAME} ${CHANNEL}" > /etc/apt/sources.list.d/mina.list
apt-get update

apt list -a "$PACKAGE"
apt-get install -y --allow-downgrades "${PACKAGE}=${VERSION}"

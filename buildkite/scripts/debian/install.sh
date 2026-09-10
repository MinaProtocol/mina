#!/bin/bash

set -u

# When invoked inside the toolchain container, the bind-mounted /workdir is
# owned by the host buildkite-agent user, which trips git's "dubious ownership"
# guard. export-git-env-vars.sh below runs git, so mark the cwd as safe first.
# Harmless on hosts (the entry just lists a trusted path).
git config --global --add safe.directory "$(pwd)"

if [[ $# -gt 2 ]] || [[ $# -lt 1 ]]; then
    echo "Usage: $0 '<debians>' '[use-sudo]'"
    exit 1
fi

if [ -z "${MINA_DEB_CODENAME:-}" ]; then
    echo "MINA_DEB_CODENAME env var is not defined"
    exit 1
fi

DEBS=$1
USE_SUDO=${2:-0}
ROOT="${ROOT:-${BUILDKITE_BUILD_ID}}"

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

# Source git environment variables first to get MINA_DEB_CODENAME
source ./buildkite/scripts/export-git-env-vars.sh

VERSION="${FORCE_VERSION:-"${MINA_DEB_VERSION}"}"

if [ "$USE_SUDO" == "1" ]; then
   SUDO="sudo"
else
   SUDO=""
fi



LOCAL_DEB_FOLDER=debs
mkdir -p $LOCAL_DEB_FOLDER

# fetch_deb honours LOCAL_DEB_SOURCE_DIR, so a caller that packaged the debs
# itself in this job installs those instead of the packaging job's cached ones.
# shellcheck source=buildkite/scripts/debian/fetch_debs.sh
source ./buildkite/scripts/debian/fetch_debs.sh

# Download required debians from bucket locally
if [ -z "$DEBS" ]; then 
    echo "DEBS env var is empty. It should contain comma separated names of debians to install"
    exit 1
else
  # shellcheck disable=SC2206
  debs=(${DEBS//,/ })
  # Install a single profile package (devnet) as the on-disk default profile
  # only when installing a bare mina-generic package without a concrete profile
  # package.
  # The per-profile leaf packages (mina-devnet-profile, mina-mainnet-profile,
  # mina-lightnet, mina-dev) all ship /etc/coda/build_config/PROFILE and are
  # therefore mutually exclusive (installing more than one collides in dpkg).
  # The convenience tent mina-${profile}-generic depends on this leaf package
  # plus mina-generic.
  # The daemon resolves its profile from MINA_PROFILE first and only falls back to
  # this file, so tests needing a different profile (e.g. single-node-tests) set
  # MINA_PROFILE themselves and override the devnet default.
  runtime_profile_needed=0
  concrete_profile_present=0
  for i in "${debs[@]}"; do
    case $i in
      mina-runtime-*)
        runtime_profile_needed=1
      ;;
      mina-devnet|mina-mainnet|mina-devnet-profile|mina-mainnet-profile|mina-lightnet|mina-dev)
        concrete_profile_present=1
      ;;
    esac
  done
  if [ "$runtime_profile_needed" == "1" ] && [ "$concrete_profile_present" == "0" ]; then
    fetch_deb $LOCAL_DEB_FOLDER "debians/$MINA_DEB_CODENAME/mina-devnet-profile_*"
  fi

  # The L2 packages (mina-<network>, mina-archive-<network>,
  # mina-rosetta-<network>) carry only symlinks and configuration; the binaries
  # live in the mina-runtime-<mina-codename> (L1) package they depend on.
  # apt-get resolves mina-package dependencies only from local .deb files, so
  # fetch the matching runtime flavor (and the profile leaf) alongside any L2
  # request.
  fetch_runtime_for() {
    local pkg="$1"
    local runtime="mina-runtime-develop"
    case $pkg in
      *-instrumented) runtime="${runtime}-instrumented" ;;
    esac
    fetch_deb $LOCAL_DEB_FOLDER "debians/$MINA_DEB_CODENAME/${runtime}_*"
  }

  fetch_profile_for() {
    local pkg="$1"
    case $pkg in
      *mainnet*) fetch_deb $LOCAL_DEB_FOLDER "debians/$MINA_DEB_CODENAME/mina-mainnet-profile_*" ;;
      *devnet*)  fetch_deb $LOCAL_DEB_FOLDER "debians/$MINA_DEB_CODENAME/mina-devnet-profile_*" ;;
    esac
  }

  for i in "${debs[@]}"; do
    case $i in
      mina-runtime-*)
        # The runtime depends on mina-logproc.
        fetch_deb $LOCAL_DEB_FOLDER "debians/$MINA_DEB_CODENAME/mina-logproc*"
      ;;
      mina-devnet|mina-mainnet|mina-devnet-instrumented|mina-mainnet-instrumented)
        fetch_deb $LOCAL_DEB_FOLDER "debians/$MINA_DEB_CODENAME/mina-logproc*"
        fetch_runtime_for "$i"
        fetch_profile_for "$i"
      ;;
      mina-archive-*|mina-rosetta-*)
        fetch_deb $LOCAL_DEB_FOLDER "debians/$MINA_DEB_CODENAME/mina-logproc*"
        fetch_runtime_for "$i"
        fetch_profile_for "$i"
      ;;
      mina-*-prefork*)
        # Download mina-logproc legacy too
        fetch_legacy_deb $LOCAL_DEB_FOLDER "debians/$MINA_DEB_CODENAME/${i}*"
    esac
    fetch_deb $LOCAL_DEB_FOLDER "debians/$MINA_DEB_CODENAME/${i}_${VERSION}_*"
  done
fi

# Enumerate the concrete .deb files that were downloaded into the local folder
# and install them directly with apt-get (local-file install). apt-get still
# resolves any non-mina dependencies from the system's normal apt sources, and
# installing local .deb files upgrades/downgrades the mina packages in place.
#
# Use absolute paths: apt-get only treats an argument as a local .deb file when
# it starts with '/' or './'. A bare relative path like 'debs/foo.deb' is
# instead parsed as the 'package/release' selector syntax (package "debs" from
# release "foo.deb"), which fails with "Unable to locate package debs".
ABS_DEB_FOLDER="$(cd "$LOCAL_DEB_FOLDER" && pwd)"
deb_files=()
while IFS= read -r -d '' f; do
  deb_files+=("$f")
done < <(find "$ABS_DEB_FOLDER" -maxdepth 1 -name '*.deb' -print0)

if [ "${#deb_files[@]}" -eq 0 ]; then
  echo "No .deb files were downloaded into '$LOCAL_DEB_FOLDER'. Nothing to install."
  exit 1
fi

# Install debians
echo "Installing mina packages: $DEBS"
echo "Installing the following local .deb files:"
printf '  %s\n' "${deb_files[@]}"

# Installing the local .deb files already replaces (upgrades/downgrades) any
# currently-installed version of the same packages, so no explicit pre-remove
# step is needed. --allow-downgrades permits installing an older version when
# the upgrade tests require it; non-mina dependencies are pulled from the
# system's normal apt sources in a single resolution pass.
$SUDO apt-get install -y --allow-downgrades --no-install-recommends "${deb_files[@]}"

# Cleaning up
rm -rf $LOCAL_DEB_FOLDER
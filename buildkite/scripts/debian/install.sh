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

# Download required debians from bucket locally
if [ -z "$DEBS" ]; then 
    echo "DEBS env var is empty. It should contain comma separated names of debians to install"
    exit 1
else
  # shellcheck disable=SC2206
  debs=(${DEBS//,/ })
  # Install a single profile package (devnet) as the on-disk default profile.
  # The three mina-<profile>-profile packages all ship /etc/coda/build_config/PROFILE
  # and are therefore mutually exclusive (installing all of them collides in dpkg).
  # The daemon resolves its profile from MINA_PROFILE first and only falls back to
  # this file, so tests needing a different profile (e.g. single-node-tests) set
  # MINA_PROFILE themselves and override the devnet default.
  ./buildkite/scripts/cache/manager.sh read --root "$ROOT" "debians/$MINA_DEB_CODENAME/mina-devnet-profile_*" $LOCAL_DEB_FOLDER
  for i in "${debs[@]}"; do
    case $i in
      mina-generic*)
        # Download mina-logproc too
          ./buildkite/scripts/cache/manager.sh read --root "$ROOT" "debians/$MINA_DEB_CODENAME/mina-logproc*" $LOCAL_DEB_FOLDER
      ;;
      mina-devnet|mina-mainnet|mina-mesa)
        # Download mina-logproc and sub debians (apps and config) too
          ./buildkite/scripts/cache/manager.sh read --root "$ROOT" "debians/$MINA_DEB_CODENAME/mina-logproc*" $LOCAL_DEB_FOLDER
          ./buildkite/scripts/cache/manager.sh read --root "$ROOT" "debians/$MINA_DEB_CODENAME/${i}-config*" $LOCAL_DEB_FOLDER
      ;;
      mina-devnet-instrumented|mina-mainnet-instrumented|mina-mesa-instrumented)
        # Instrumented daemon depends on mina-logproc and the non-instrumented
        # network-config deb (config files are the same for both flavors).
          network_pkg=${i%-instrumented}
          ./buildkite/scripts/cache/manager.sh read --root "$ROOT" "debians/$MINA_DEB_CODENAME/mina-logproc*" $LOCAL_DEB_FOLDER
          ./buildkite/scripts/cache/manager.sh read --root "$ROOT" "debians/$MINA_DEB_CODENAME/${network_pkg}-config*" $LOCAL_DEB_FOLDER
      ;;
      mina-*-prefork*)
        # Download mina-logproc legacy too
        ./buildkite/scripts/cache/manager.sh read --root "legacy" "debians/$MINA_DEB_CODENAME/${i}*" $LOCAL_DEB_FOLDER
    esac
    ./buildkite/scripts/cache/manager.sh read --root "$ROOT" "debians/$MINA_DEB_CODENAME/${i}_${VERSION}_*" $LOCAL_DEB_FOLDER
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
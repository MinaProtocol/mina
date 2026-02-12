#!/bin/bash

set -u

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

# Configure APT mirrors if enabled (for CI reliability)
if [ "${APT_MIRROR_ENABLED:-false}" = "true" ] && [ -f "./buildkite/scripts/apt/configure-mirrors.sh" ]; then
    echo "Configuring APT mirrors..."
    bash ./buildkite/scripts/apt/configure-mirrors.sh || true
fi

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
  for i in "${debs[@]}"; do
    case $i in
      mina-testnet-generic*)
        # Download mina-logproc too
          ./buildkite/scripts/cache/manager.sh read --root "$ROOT" "debians/$MINA_DEB_CODENAME/mina-logproc*" $LOCAL_DEB_FOLDER
      ;;
      mina-devnet|mina-mainnet)
        # Download mina-logproc and sub debians (apps and config) too
          ./buildkite/scripts/cache/manager.sh read --root "$ROOT" "debians/$MINA_DEB_CODENAME/mina-logproc*" $LOCAL_DEB_FOLDER
          ./buildkite/scripts/cache/manager.sh read --root "$ROOT" "debians/$MINA_DEB_CODENAME/${i}-config*" $LOCAL_DEB_FOLDER
      ;;
      mina-devnet-legacy|mina-mainnet-legacy)
        # Download mina-logproc legacy too
        ./buildkite/scripts/cache/manager.sh read --root "legacy" "debians/$MINA_DEB_CODENAME/${i}*" $LOCAL_DEB_FOLDER
    esac
    ./buildkite/scripts/cache/manager.sh read --root "$ROOT" "debians/$MINA_DEB_CODENAME/${i}_${VERSION}_*" $LOCAL_DEB_FOLDER
  done
fi

debs_with_version=()
for i in "${debs[@]}"; do
   debs_with_version+=("${i}=${VERSION}")
done

# Start aptly
source ./scripts/debian/aptly.sh start --codename $MINA_DEB_CODENAME --debians $LOCAL_DEB_FOLDER --component unstable --clean --background --wait

# Install debians
echo "Installing mina packages: $DEBS"
echo "deb [trusted=yes] http://localhost:8080 $MINA_DEB_CODENAME unstable" | $SUDO tee /etc/apt/sources.list.d/mina.list

# Update apt packages for the new repo, preserving all others
$SUDO apt-get update --yes -o Dir::Etc::sourcelist="sources.list.d/mina.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
$SUDO apt-get remove --yes "${debs[@]}"
$SUDO apt-get install --yes --allow-downgrades "${debs_with_version[@]}"



# Cleaning up
source ./scripts/debian/aptly.sh stop  --clean

rm -rf $LOCAL_DEB_FOLDER
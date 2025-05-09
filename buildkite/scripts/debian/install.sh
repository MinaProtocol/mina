#!/bin/bash

# ==============================================================================
# install.sh
#
# This script downloads and installs specific MINA .deb packages from a local
# cache or remote bucket using a local aptly server. It supports optional sudo
# usage and expects the MINA_DEB_CODENAME and MINA_DEB_VERSION environment
# variables to be set.
#
# Usage:
#   ./install.sh '<comma-separated-deb-names>' '[use-sudo: 0|1]'
#
# Example:
#   MINA_DEB_CODENAME=focal MINA_DEB_VERSION=1.0.0 \
#     ./install.sh 'mina-mainnet,mina-logproc' 1
#
# Recognized Debian package names (partial match or exact):
#   - mina-mainnet
#   - mina-devnet
#   - mina-berkeley*
#   - mina-logproc
#   - mina-create-legacy-genesis
#
# These are used to identify which .deb packages to download and install.
# ==============================================================================

# Usage validation
if [[ $# -gt 2 || $# -lt 1 ]]; then
  echo "Usage: $0 '<debians>' '[use-sudo]'"
  exit 1
fi

# Ensure required environment variable is set
if [ -z "${MINA_DEB_CODENAME}" ]; then
  echo "MINA_DEB_CODENAME env var is not defined"
  exit 1
fi

# Input arguments
DEBS="$1"
USE_SUDO="${2:-0}"
SUDO=""

if [ "$USE_SUDO" == "1" ]; then
  SUDO="sudo"
fi

# Prepare working directory
LOCAL_DEB_FOLDER="debs"
mkdir -p "$LOCAL_DEB_FOLDER"
source ./buildkite/scripts/export-git-env-vars.sh

# Download required debians
if [ -z "$DEBS" ]; then
  echo "DEBS env var is empty. It should contain comma-delimited names of " \
       "debians to install"
  exit 1
else
  IFS=',' read -ra debs <<< "$DEBS"
  for deb in "${debs[@]}"; do
    case "$deb" in
      mina-berkeley* | mina-devnet | mina-mainnet)
        # Download mina-logproc too
        ./buildkite/scripts/cache/manager.sh read \
          "debians/$MINA_DEB_CODENAME/mina-logproc*" "$LOCAL_DEB_FOLDER"
        ;;
      mina-create-legacy-genesis)
        # Download static debians
        ./buildkite/scripts/cache/manager.sh read --root debs \
          "$MINA_DEB_CODENAME/$deb*" "$LOCAL_DEB_FOLDER"
        ;;
    esac

    ./buildkite/scripts/cache/manager.sh read \
      "debians/$MINA_DEB_CODENAME/${deb}_*" "$LOCAL_DEB_FOLDER"
  done
fi

# Prepare debians with version
debs_with_version=()
for deb in "${debs[@]}"; do
  debs_with_version+=("${deb}=${MINA_DEB_VERSION}")
done

# Start aptly server
source ./scripts/debian/aptly.sh start \
  --codename "$MINA_DEB_CODENAME" \
  --debians "$LOCAL_DEB_FOLDER" \
  --component unstable \
  --clean \
  --background \
  --wait

# Add local repo and install packages
echo "Installing mina packages: $DEBS"

echo "deb [trusted=yes] http://localhost:8080 $MINA_DEB_CODENAME unstable" |
  $SUDO tee /etc/apt/sources.list.d/mina.list

$SUDO apt-get update --yes \
  -o Dir::Etc::sourcelist="sources.list.d/mina.list" \
  -o Dir::Etc::sourceparts="-" \
  -o APT::Get::List-Cleanup="0"

$SUDO apt-get remove --yes "${debs[@]}"
$SUDO apt-get install --yes --allow-downgrades "${debs_with_version[@]}"

# Cleanup
source ./scripts/debian/aptly.sh stop --clean

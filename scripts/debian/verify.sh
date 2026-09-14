#!/usr/bin/env bash
set -eo pipefail

REPO=packages.o1test.net
SIGNED=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/verify-inside-docker/setup.sh"
CHECK_SCRIPTS_DIR="$SCRIPT_DIR/../verify"

function usage() {
  echo "Usage: $0 -c <channel> -r <repository> -v <version> -p <package> -m <codename> [-s]"
  echo "  -c, --channel    Channel to use (stable, beta, dev)"
  echo "  -r, --repo       Repository to use (default: packages.o1test.net)"
  echo "  -v, --version    Version to install"
  echo "  -p, --package    Package to install"
  echo "  -m, --codename   Codename of the distribution (focal, bullseye)"
  echo "  -a, --arch       Architecture (default: amd64)"
  echo "  -s, --signed     Add the repository signing key"
}

while [[ "$#" -gt 0 ]]; do case $1 in
  -c|--channel) CHANNEL="$2"; shift;;
  -r|--repo) REPO="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  -p|--package) PACKAGE="$2"; shift;;
  -m|--codename) CODENAME="$2"; shift;;
  -a|--arch) ARCH="$2"; shift;;
  -s|--signed) SIGNED=1; ;;
  -h|--help) usage; exit 0;;
  *) echo "Unknown parameter passed: $1"; usage;  exit 1;;
esac; shift; done

if [ -z "${PACKAGE:-}" ]; then
  echo "No package defined. Did you forget to pass --package?"
  usage; exit 1;
fi

if [ -z "${VERSION:-}" ]; then
  echo "No version defined. Did you forget to pass --version?"
  usage; exit 1;
fi

if [ -z "${CODENAME:-}" ]; then
  echo "No codename defined. Did you forget to pass --codename?"
  usage; exit 1;
fi

if [ -z "${CHANNEL:-}" ]; then
  echo "No channel defined. Did you forget to pass --channel?"
  usage; exit 1;
fi

if [ -z "${REPO:-}" ]; then
  echo "No repository defined. Did you forget to pass --repo?"
  usage; exit 1;
fi

ARCH="${ARCH:-amd64}"

# Resolve which check script to run
# shellcheck source=../verify/resolve-check-script.sh
source "$CHECK_SCRIPTS_DIR/resolve-check-script.sh" "$PACKAGE"
CHECK_SCRIPT_NAME=$(basename "$CHECK_SCRIPT")

case $CODENAME in
  bullseye|bookworm) DOCKER_IMAGE="debian:$CODENAME" ;;
  focal|noble|jammy) DOCKER_IMAGE="ubuntu:$CODENAME" ;;
  *) echo "Unknown codename passed: $CODENAME"; exit 1;;
esac

if [[ "$SIGNED" == 1 ]]; then
  TRUSTED_FLAG=""
else
  TRUSTED_FLAG="[trusted=yes]"
fi

echo "Testing $PACKAGE on $DOCKER_IMAGE"

# Mount the setup script and shared check scripts into the container.
# 1. setup.sh installs the package from the debian repository
# 2. The shared check script verifies the installed binaries
if docker run --platform "linux/$ARCH" --rm \
  -v "$SETUP_SCRIPT:/verify/setup.sh:ro" \
  -v "$CHECK_SCRIPTS_DIR:/checks:ro" \
  "$DOCKER_IMAGE" \
  bash -c "source /verify/setup.sh '$PACKAGE' '$VERSION' '$REPO' '$CODENAME' '$CHANNEL' '$SIGNED' '$TRUSTED_FLAG' && bash /checks/$CHECK_SCRIPT_NAME"; then
  echo 'OK: ALL WORKED FINE!'
else
  echo 'KO: ERROR!!!'
  exit 1
fi

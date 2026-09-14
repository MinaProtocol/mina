#!/usr/bin/env bash

set -euox pipefail

CLEAR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

# Configuration - can be overridden via environment variables
REPO="${REPO:-packages.o1test.net}"
CODENAME="${CODENAME:-bullseye}"
CHANNEL="${CHANNEL:-alpha}"
PACKAGE="${PACKAGE:-mina-devnet}"
VERSION="${VERSION:-"3.3.0-alpha1*"}"


# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

git config --global --add safe.directory /workdir

function log_info() {
    echo -e "${GREEN}[INFO]${CLEAR} $*"
}

function log_warn() {
    echo -e "${YELLOW}[WARN]${CLEAR} $*"
}

function log_error() {
    echo -e "${RED}[ERROR]${CLEAR} $*"
}

function usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Test debian package upgrade from packages.o1test.net to a new version from cache."
    echo ""
    echo "Options:"
    echo "  -r, --repo          Repository URL (default: packages.o1test.net)"
    echo "  -c, --codename      Debian codename (default: bullseye)"
    echo "  -C, --channel       Repository channel (default: alpha)"
    echo "  -p, --package       Package name (default: mina-devnet)"
    echo "  -v, --version       Package version (default: 3.3.0-alpha1*)"
    echo "  -b, --build-id      Buildkite build ID (required, or set BUILDKITE_BUILD_ID)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --package mina-devnet --version 3.3.0-alpha1 --build-id abc123"
}


# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo)
            REPO="$2"
            shift 2
            ;;
        -c|--codename)
            CODENAME="$2"
            shift 2
            ;;
        -C|--channel)
            CHANNEL="$2"
            shift 2
            ;;
        -p|--package)
            PACKAGE="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -b|--build-id)
            BUILDKITE_BUILD_ID="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "${BUILDKITE_BUILD_ID:-}" ]]; then
    log_error "BUILDKITE_BUILD_ID must be set (or use --build-id option)"
    exit 1
fi

# Detect sudo
if [[ "${EUID}" -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Step 1: Install current mina from packages.o1test.net
log_info "--- Step 1: Installing ${PACKAGE} from ${REPO} ---"

echo "deb [trusted=yes] https://${REPO} ${CODENAME} ${CHANNEL}" | $SUDO tee /etc/apt/sources.list.d/mina-test.list

./buildkite/scripts/debian/update.sh

$SUDO apt-get remove -y --allow-downgrades "${PACKAGE}" || {
    log_error "Failed to remove existing ${PACKAGE} from ${REPO}"
    exit 1
}

$SUDO apt-get install -y --allow-downgrades "${PACKAGE}=${VERSION}" || {
    log_error "Failed to install ${PACKAGE}=${VERSION} from ${REPO}"
    exit 1
}
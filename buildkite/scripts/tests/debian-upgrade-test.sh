#!/usr/bin/env bash

# Test script for verifying debian package upgrades work correctly.
# This test:
# 1. Installs the current mina-devnet from packages.o1test.net
# 2. Records config files and version before upgrade
# 3. Downloads new debian from Hetzner cache
# 4. Upgrades the package
# 5. Verifies config files and version after upgrade

set -euox pipefail

CLEAR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

# Configuration - can be overridden via environment variables
REPO="${REPO:-packages.o1test.net}"
CODENAME="${CODENAME:-bullseye}"
CHANNEL="${CHANNEL:-devnet}"
PACKAGE="${PACKAGE:-mina-devnet}"
NEW_DEBIAN_PATH="${NEW_DEBIAN_PATH:-}"  # Path pattern in cache, e.g., "debians/bullseye/mina-devnet_*.deb"

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh


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
    echo "  -C, --channel       Repository channel (default: devnet)"
    echo "  -p, --package       Package name (default: mina-devnet)"
    echo "  -n, --new-debian    Path to new debian in cache (required)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --new-debian 'debians/bullseye/mina-devnet_*.deb'"
}

# Function to extract the first 8 characters of the commit hash from a version string
get_short_commit() {
    local version_str="$1"
    echo "$version_str" | grep -oP '[\da-f]{8,40}' | head -1 | cut -c1-8 || echo "unknown"
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
        -n|--new-debian)
            NEW_DEBIAN_PATH="$2"
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

# Validate required parameters
if [[ -z "${NEW_DEBIAN_PATH}" ]]; then
    log_error "New debian path is required. Use --new-debian option."
    usage
    exit 1
fi

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

CONFIG_DIR="/var/lib/coda"
LOCAL_DEB_DIR="/tmp/debian-upgrade-test"

log_info "=== Debian Upgrade Test ==="
log_info "Repository: ${REPO}"
log_info "Codename: ${CODENAME}"
log_info "Channel: ${CHANNEL}"
log_info "Package: ${PACKAGE}"
log_info "New debian path: ${NEW_DEBIAN_PATH}"

# Step 1: Install current mina from packages.o1test.net
log_info "--- Step 1: Installing ${PACKAGE} from ${REPO} ---"

echo "deb [trusted=yes] https://${REPO} ${CODENAME} ${CHANNEL}" | $SUDO tee /etc/apt/sources.list.d/mina-test.list

./buildkite/scripts/debian/update.sh

$SUDO apt-get install -y -qq lsb-release ca-certificates wget gnupg

log_info "Available versions of ${PACKAGE}:"
apt-cache policy "${PACKAGE}"

$SUDO apt-get install -y --allow-downgrades "${PACKAGE}"

# Step 2: Record pre-upgrade state
log_info "--- Step 2: Recording pre-upgrade state ---"

PRE_COMMIT=$(mina --version 2>&1 || echo "version check failed")
log_info "Pre-upgrade mina version: ${PRE_COMMIT}"

# Extract the first 7 characters of the commit hash
PRE_COMMIT_SHORT=$(get_short_commit "${PRE_COMMIT}")
log_info "Pre-upgrade mina short commit: ${PRE_COMMIT_SHORT}"

# List config files before upgrade
log_info "Config file before upgrade:"
PRE_CONFIG_FILE=${CONFIG_DIR}/config_${PRE_COMMIT_SHORT}.json

if [[ -f "${PRE_CONFIG_FILE}" ]]; then
    log_info "Found config file: ${PRE_CONFIG_FILE}"
    log_info "  - $(basename "$PRE_CONFIG_FILE"): $(stat -c %s "$PRE_CONFIG_FILE") bytes"
else
    log_error "No config_${PRE_COMMIT_SHORT}.json file found before upgrade"
    exit 1
fi

# Step 3: Download new debian from cache
log_info "--- Step 3: Downloading new debian from cache ---"

mkdir -p "${LOCAL_DEB_DIR}"

./buildkite/scripts/cache/manager.sh read "${NEW_DEBIAN_PATH}" "${LOCAL_DEB_DIR}"

NEW_DEB_FILE=$(ls "${LOCAL_DEB_DIR}"/*.deb 2>/dev/null | head -1)
if [[ -z "${NEW_DEB_FILE}" ]]; then
    log_error "No .deb file found in ${LOCAL_DEB_DIR}"
    exit 1
fi

log_info "Downloaded from cache: ${NEW_DEB_FILE}"

# Step 4: Upgrade the package
log_info "--- Step 4: Upgrading package ---"

if [[ -n "$SUDO" ]]; then
    source buildkite/scripts/debian/install.sh "mina-devnet" 1
else
    source buildkite/scripts/debian/install.sh "mina-devnet"
fi

# Step 5: Verify post-upgrade state
log_info "--- Step 5: Verifying post-upgrade state ---"

POST_COMMIT=$(mina --version 2>&1)
log_info "Post-upgrade mina version: ${POST_COMMIT}"

POST_COMMIT_SHORT=$(get_short_commit "${POST_COMMIT}")
log_info "Post-upgrade commit: ${POST_COMMIT_SHORT}"


POST_CONFIG_FILE="${CONFIG_DIR}"/config_${POST_COMMIT_SHORT}.json
if [[ -f "${POST_CONFIG_FILE}" ]]; then
    log_info "Found config file: ${POST_CONFIG_FILE}"
    log_info "  - $(basename "$POST_CONFIG_FILE"): $(stat -c %s "$POST_CONFIG_FILE") bytes"
else
    log_error "No config_${POST_COMMIT_SHORT}.json file found after upgrade"
    exit 1
fi

log_info "=== Debian Upgrade Test PASSED ==="
log_info "Successfully upgraded from ${PRE_COMMIT} to ${POST_COMMIT}"

# Cleanup
rm -rf "${LOCAL_DEB_DIR}"

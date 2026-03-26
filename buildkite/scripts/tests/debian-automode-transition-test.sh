#!/usr/bin/env bash

# Integration test for the full automode transition lifecycle:
#   mina-devnet (v1) → mina-devnet-automode (v2) → mina-devnet (v3)
#
# Validates that:
# - mina-devnet installs cleanly
# - mina-devnet-automode replaces mina-devnet via apt
# - mina-devnet (higher version) replaces automode and restores normal layout
# - No automode-specific files remain after the final transition
#
# Prerequisites:
#   - Built debs available in cache (depends on debian build CI step)
#   - Running inside a toolchain container with apt/dpkg/fakeroot/aptly
#
# Usage:
#   debian-automode-transition-test.sh --codename <codename> --network <network>

set -euox pipefail

CLEAR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

export DEBIAN_FRONTEND=noninteractive

git config --global --add safe.directory /workdir
source buildkite/scripts/export-git-env-vars.sh

SESSION_DIR="./scripts/debian/session"

################################################################################
# Logging
################################################################################

log_info()  { echo -e "${GREEN}[INFO]${CLEAR} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${CLEAR} $*"; }
log_error() { echo -e "${RED}[ERROR]${CLEAR} $*"; }

################################################################################
# CLI
################################################################################

CODENAME="bullseye"
NETWORK="devnet"
APTLY_PORT=8080

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --codename    Debian codename (default: bullseye)"
    echo "  -N, --network     Network name (default: devnet)"
    echo "  -h, --help        Show this help"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--codename) CODENAME="$2"; shift 2 ;;
        -N|--network)  NETWORK="$2"; shift 2 ;;
        -h|--help)     usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if [[ -z "${BUILDKITE_BUILD_ID:-}" ]]; then
    log_error "BUILDKITE_BUILD_ID must be set"
    exit 1
fi

################################################################################
# Setup
################################################################################

WORKDIR=$(mktemp -d)
DEB_DIR="${WORKDIR}/debs"
REPO_DIR="${WORKDIR}/repo"
VERSIONED_DIR="${WORKDIR}/versioned"

mkdir -p "${DEB_DIR}" "${REPO_DIR}" "${VERSIONED_DIR}"

cleanup() {
    log_info "Cleaning up..."
    ./scripts/debian/aptly.sh stop --clean 2>/dev/null || true
    rm -rf "${WORKDIR}"
}
trap cleanup EXIT

# Detect sudo
if [[ "${EUID}" -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

PKG_DAEMON="mina-${NETWORK}"
PKG_AUTOMODE="mina-${NETWORK}-automode"
PKG_CONFIG="mina-${NETWORK}-config"
PKG_POSTFORK="mina-${NETWORK}-postfork-mesa"
PKG_PREFORK="mina-${NETWORK}-prefork-mesa"

# Automode-specific paths that should NOT exist after restoring mina-devnet
AUTOMODE_PATHS=(
    "/usr/local/bin/mina-dispatch"
    "/etc/default/mina-dispatch"
    "/usr/lib/mina/mesa"
    "/usr/lib/mina/berkeley"
)

# Normal mina-devnet paths that SHOULD exist after restore
DAEMON_PATHS=(
    "/usr/local/bin/mina"
    "/usr/local/bin/coda-libp2p_helper"
    "/usr/local/bin/mina-create-genesis"
)

################################################################################
# Step 1: Download debs from cache
################################################################################

log_info "=== Step 1: Download debs from cache ==="

# Download all relevant debs for this codename
./buildkite/scripts/cache/manager.sh read "debians/${CODENAME}/${PKG_DAEMON}_*" "${DEB_DIR}"
./buildkite/scripts/cache/manager.sh read "debians/${CODENAME}/${PKG_AUTOMODE}_*" "${DEB_DIR}"
./buildkite/scripts/cache/manager.sh read "debians/${CODENAME}/${PKG_CONFIG}_*" "${DEB_DIR}"
./buildkite/scripts/cache/manager.sh read "debians/${CODENAME}/${PKG_POSTFORK}_*" "${DEB_DIR}"
./buildkite/scripts/cache/manager.sh read "debians/${CODENAME}/${PKG_PREFORK}_*" "${DEB_DIR}"
./buildkite/scripts/cache/manager.sh read "debians/${CODENAME}/mina-logproc_*" "${DEB_DIR}"

log_info "Downloaded debs:"
ls -la "${DEB_DIR}"/*.deb

################################################################################
# Step 2: Create versioned variants using deb-session
################################################################################

log_info "=== Step 2: Create versioned package variants ==="

# Original version from the build
ORIG_DAEMON_DEB=$(ls "${DEB_DIR}"/${PKG_DAEMON}_*.deb | head -1)
ORIG_AUTOMODE_DEB=$(ls "${DEB_DIR}"/${PKG_AUTOMODE}_*.deb | head -1)
ORIG_CONFIG_DEB=$(ls "${DEB_DIR}"/${PKG_CONFIG}_*.deb | head -1)
ORIG_POSTFORK_DEB=$(ls "${DEB_DIR}"/${PKG_POSTFORK}_*.deb | head -1)
ORIG_PREFORK_DEB=$(ls "${DEB_DIR}"/${PKG_PREFORK}_*.deb | head -1)
ORIG_LOGPROC_DEB=$(ls "${DEB_DIR}"/mina-logproc_*.deb | head -1)

reversion_deb() {
    local input_deb="$1"
    local new_version="$2"
    local output_deb="$3"
    local session_dir="${WORKDIR}/session_tmp"

    rm -rf "${session_dir}"
    "${SESSION_DIR}/deb-session-open.sh" "${input_deb}" "${session_dir}"
    "${SESSION_DIR}/deb-session-reversion.sh" "${session_dir}" "${new_version}"
    "${SESSION_DIR}/deb-session-save.sh" "${session_dir}" "${output_deb}"
    rm -rf "${session_dir}"
}

V1="1.0.0-transition-test"
V2="2.0.0-transition-test"
V3="3.0.0-transition-test"

# V1: mina-devnet + config + logproc (pre-hardfork)
reversion_deb "${ORIG_DAEMON_DEB}"  "${V1}" "${REPO_DIR}/${PKG_DAEMON}_${V1}_amd64.deb"
reversion_deb "${ORIG_CONFIG_DEB}"  "${V1}" "${REPO_DIR}/${PKG_CONFIG}_${V1}_all.deb"
reversion_deb "${ORIG_LOGPROC_DEB}" "${V1}" "${REPO_DIR}/mina-logproc_${V1}_amd64.deb"

# V2: automode + postfork + prefork + config + logproc (hardfork)
reversion_deb "${ORIG_AUTOMODE_DEB}" "${V2}" "${REPO_DIR}/${PKG_AUTOMODE}_${V2}_all.deb"
reversion_deb "${ORIG_POSTFORK_DEB}" "${V2}" "${REPO_DIR}/${PKG_POSTFORK}_${V2}_amd64.deb"
reversion_deb "${ORIG_PREFORK_DEB}"  "${V2}" "${REPO_DIR}/${PKG_PREFORK}_${V2}_amd64.deb"
reversion_deb "${ORIG_CONFIG_DEB}"   "${V2}" "${REPO_DIR}/${PKG_CONFIG}_${V2}_all.deb"
reversion_deb "${ORIG_LOGPROC_DEB}"  "${V2}" "${REPO_DIR}/mina-logproc_${V2}_amd64.deb"

# V3: mina-devnet + config + logproc (post-hardfork, back to normal)
reversion_deb "${ORIG_DAEMON_DEB}"  "${V3}" "${REPO_DIR}/${PKG_DAEMON}_${V3}_amd64.deb"
reversion_deb "${ORIG_CONFIG_DEB}"  "${V3}" "${REPO_DIR}/${PKG_CONFIG}_${V3}_all.deb"
reversion_deb "${ORIG_LOGPROC_DEB}" "${V3}" "${REPO_DIR}/mina-logproc_${V3}_amd64.deb"

log_info "Versioned packages:"
ls -la "${REPO_DIR}"/*.deb

################################################################################
# Step 3: Start local apt repo
################################################################################

log_info "=== Step 3: Start local apt repository ==="

./scripts/debian/aptly.sh start \
    --codename "${CODENAME}" \
    --debians "${REPO_DIR}" \
    --component unstable \
    --clean \
    --background \
    --wait \
    --port "${APTLY_PORT}"

# Add local repo to apt sources
$SUDO bash -c "echo 'deb [trusted=yes] http://localhost:${APTLY_PORT}/ ${CODENAME} unstable' > /etc/apt/sources.list.d/transition-test.list"
$SUDO apt-get update -qq

log_info "Available packages:"
apt-cache showpkg "${PKG_DAEMON}" 2>/dev/null | head -20 || true
apt-cache showpkg "${PKG_AUTOMODE}" 2>/dev/null | head -20 || true

################################################################################
# Step 4: Install mina-devnet v1 (pre-hardfork state)
################################################################################

log_info "=== Step 4: Install ${PKG_DAEMON} v1 ==="

$SUDO apt-get install -y -qq --allow-downgrades "${PKG_DAEMON}=${V1}"

log_info "Installed ${PKG_DAEMON} v1"
dpkg -l "${PKG_DAEMON}" 2>/dev/null | tail -1

# Verify mina binary is a real file (not a symlink to dispatcher)
if [[ -L "/usr/local/bin/mina" ]]; then
    log_error "/usr/local/bin/mina should be a real binary in v1, not a symlink"
    exit 1
fi
log_info "PASS: /usr/local/bin/mina is a real binary"

# Verify no automode paths exist
for path in "${AUTOMODE_PATHS[@]}"; do
    if [[ -e "$path" ]]; then
        log_error "Automode path should not exist in v1: $path"
        exit 1
    fi
done
log_info "PASS: No automode paths in v1"

################################################################################
# Step 5: Upgrade to mina-devnet-automode v2 (hardfork transition)
################################################################################

log_info "=== Step 5: Upgrade to ${PKG_AUTOMODE} v2 ==="

$SUDO apt-get install -y -qq --allow-downgrades "${PKG_AUTOMODE}=${V2}"

log_info "Package state after automode install:"
dpkg -l "${PKG_AUTOMODE}" 2>/dev/null | tail -1 || true
dpkg -l "${PKG_POSTFORK}" 2>/dev/null | tail -1 || true
dpkg -l "${PKG_PREFORK}" 2>/dev/null | tail -1 || true
dpkg -l "${PKG_DAEMON}" 2>/dev/null | tail -1 || true

# mina-devnet should be removed (replaced by automode)
if dpkg -l "${PKG_DAEMON}" 2>/dev/null | grep -q "^ii"; then
    log_error "${PKG_DAEMON} should have been replaced by ${PKG_AUTOMODE}"
    exit 1
fi
log_info "PASS: ${PKG_DAEMON} removed by automode transition"

# mina-dispatch should exist (from postfork package)
if [[ ! -e "/usr/local/bin/mina-dispatch" ]]; then
    log_error "mina-dispatch should exist after automode install"
    exit 1
fi
log_info "PASS: mina-dispatch present"

# /usr/local/bin/mina should be a symlink to mina-dispatch
if [[ ! -L "/usr/local/bin/mina" ]]; then
    log_error "/usr/local/bin/mina should be a symlink in automode"
    exit 1
fi
log_info "PASS: /usr/local/bin/mina is a symlink (automode dispatcher)"

################################################################################
# Step 6: Restore mina-devnet v3 (post-hardfork, back to normal)
################################################################################

log_info "=== Step 6: Restore ${PKG_DAEMON} v3 ==="

$SUDO apt-get install -y -qq --allow-downgrades "${PKG_DAEMON}=${V3}"

# automode metapackage conflicts with mina-devnet, so apt should remove it.
# The prefork/postfork sub-packages were only dependencies of automode, so
# they become orphans. Run autoremove to clean them up (simulates operator
# running apt autoremove after a transition).
$SUDO apt-get autoremove -y -qq

log_info "Package state after restore:"
dpkg -l "${PKG_DAEMON}" 2>/dev/null | tail -1 || true
dpkg -l "${PKG_AUTOMODE}" 2>/dev/null | tail -1 || true
dpkg -l "${PKG_POSTFORK}" 2>/dev/null | tail -1 || true
dpkg -l "${PKG_PREFORK}" 2>/dev/null | tail -1 || true

# mina-devnet v3 should be installed
if ! dpkg -l "${PKG_DAEMON}" 2>/dev/null | grep -q "^ii"; then
    log_error "${PKG_DAEMON} v3 should be installed"
    exit 1
fi
log_info "PASS: ${PKG_DAEMON} v3 installed"

# Automode metapackage should be gone
if dpkg -l "${PKG_AUTOMODE}" 2>/dev/null | grep -q "^ii"; then
    log_error "${PKG_AUTOMODE} should have been removed"
    exit 1
fi
log_info "PASS: ${PKG_AUTOMODE} removed"

# Postfork/prefork should be gone (removed by autoremove)
if dpkg -l "${PKG_POSTFORK}" 2>/dev/null | grep -q "^ii"; then
    log_error "${PKG_POSTFORK} should have been removed by autoremove"
    exit 1
fi
log_info "PASS: ${PKG_POSTFORK} removed"

if dpkg -l "${PKG_PREFORK}" 2>/dev/null | grep -q "^ii"; then
    log_error "${PKG_PREFORK} should have been removed by autoremove"
    exit 1
fi
log_info "PASS: ${PKG_PREFORK} removed"

# Verify /usr/local/bin/mina is a real binary again (not a symlink)
if [[ -L "/usr/local/bin/mina" ]]; then
    log_error "/usr/local/bin/mina should be a real binary after restore, not a symlink"
    exit 1
fi
log_info "PASS: /usr/local/bin/mina is a real binary again"

# Verify daemon binaries exist
for path in "${DAEMON_PATHS[@]}"; do
    if [[ ! -e "$path" ]]; then
        log_error "Daemon path should exist after restore: $path"
        exit 1
    fi
done
log_info "PASS: All daemon binaries present"

# Verify automode-specific files are gone
AUTOMODE_LEFTOVER=0
for path in "${AUTOMODE_PATHS[@]}"; do
    if [[ -e "$path" ]]; then
        log_error "Automode leftover found: $path"
        AUTOMODE_LEFTOVER=1
    fi
done

if [[ "${AUTOMODE_LEFTOVER}" -eq 1 ]]; then
    log_error "Automode files were not cleaned up during transition back to ${PKG_DAEMON}"
    exit 1
fi
log_info "PASS: No automode files remain"

################################################################################
# Done
################################################################################

log_info "=== Debian Automode Transition Test PASSED ==="
log_info "Successfully tested: ${PKG_DAEMON}(v1) → ${PKG_AUTOMODE}(v2) → ${PKG_DAEMON}(v3)"

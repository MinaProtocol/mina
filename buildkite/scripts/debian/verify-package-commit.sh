#!/usr/bin/env bash

# Verify that an installed Debian package (and its dependencies) resolve to the
# expected versions AND that each installed `mina` binary self-reports the git
# commit encoded in its owning package version.
#
# Runs INSIDE a container of the target codename (the Buildkite step supplies the
# per-codename image, same as install_official.sh). Two independent checks:
#
#   1. Integrity   - every installed `mina` binary reports the commit found in the
#                    tail of its OWNING package version (catches corrupt / mismatched
#                    builds). Handles the automode metapackage which ships two binaries
#                    (berkeley/prefork + mesa/postfork) owned by different sub-packages.
#
#   2. Resolution  - optional EXPECT assertions ("pkg=version" pairs) confirm apt
#                    actually resolved each dependency to the intended version. This is
#                    what catches the `>=` dependency trap, where a stale prefork that
#                    sorts lexically higher (e.g. "compatible-28bdb6d" > "automode-fix-...")
#                    silently satisfies the constraint. The integrity check alone does
#                    NOT catch this, since the wrong binary still matches its own package.
#
# Exit non-zero on any mismatch so the Buildkite job fails.

set -euo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

# Configuration - can be overridden via environment variables
REPO="${REPO:-packages.o1test.net}"
CODENAME="${CODENAME:-bullseye}"
CHANNEL="${CHANNEL:-umt}"
PACKAGE="${PACKAGE:-}"
VERSION="${VERSION:-}"
# Space/comma separated "pkg=version" assertions for resolved dependencies.
EXPECT="${EXPECT:-}"

export DEBIAN_FRONTEND=noninteractive

function log_info()  { echo -e "${GREEN}[INFO]${CLEAR} $*"; }
function log_warn()  { echo -e "${YELLOW}[WARN]${CLEAR} $*"; }
function log_error() { echo -e "${RED}[ERROR]${CLEAR} $*"; }

function usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install a mina Debian package and verify resolved versions + binary commits.

Options:
  -r, --repo       Repository host (default: packages.o1test.net)
  -c, --codename   Debian/Ubuntu codename (default: bullseye)
  -C, --channel    Repository channel/component (default: umt)
  -p, --package    Package to install, e.g. mina-mesa-mut-automode (required)
  -v, --version    Exact version to install (required)
  -e, --expect     Space-separated "pkg=version" assertions on resolved deps
  -h, --help       Show this help

Environment overrides: REPO CODENAME CHANNEL PACKAGE VERSION EXPECT

Examples:
  # Automode: assert it did NOT fall into the '>=' trap on the prefork
  $0 -p mina-mesa-mut-automode -v 4.0.0-rc1-mesa-mut-d7513d4 \\
     -e "mina-mesa-mut-prefork-mesa=3.4.0-alpha1-automode-fix-3d88e1c916 \\
         mina-mesa-mut-postfork-mesa=4.0.0-rc1-mesa-mut-d7513d4"

  # Legacy
  $0 -p mina-mesa-mut -v 3.4.0-alpha1-mesa-mut-stop-slot-1a6a8f5
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo)     REPO="$2"; shift 2 ;;
        -c|--codename) CODENAME="$2"; shift 2 ;;
        -C|--channel)  CHANNEL="$2"; shift 2 ;;
        -p|--package)  PACKAGE="$2"; shift 2 ;;
        -v|--version)  VERSION="$2"; shift 2 ;;
        -e|--expect)   EXPECT="$2"; shift 2 ;;
        -h|--help)     usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if [[ -z "${PACKAGE}" || -z "${VERSION}" ]]; then
    log_error "--package and --version are required"
    usage
    exit 1
fi

if [[ "${EUID}" -eq 0 ]]; then SUDO=""; else SUDO="sudo"; fi

# ca-certificates is required: packages.o1test.net redirects HTTP->HTTPS, and apt
# fails the TLS handshake without it (reporting a misleading "Unable to locate package").
log_info "--- Installing prerequisites (ca-certificates) ---"
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq ca-certificates

log_info "--- Adding ${REPO} ${CODENAME}/${CHANNEL} and installing ${PACKAGE}=${VERSION} ---"
echo "deb [trusted=yes] https://${REPO} ${CODENAME} ${CHANNEL}" | $SUDO tee /etc/apt/sources.list.d/mina-verify.list
$SUDO apt-get update -o Acquire::Retries=5
$SUDO apt-get install -y --allow-downgrades "${PACKAGE}=${VERSION}"

FAILED=0

# --- Check 2: resolved dependency versions (the '>=' trap) ---
if [[ -n "${EXPECT}" ]]; then
    log_info "--- Asserting resolved dependency versions ---"
    # shellcheck disable=SC2206
    for pair in ${EXPECT//,/ }; do
        want_pkg="${pair%%=*}"
        want_ver="${pair#*=}"
        got_ver="$(dpkg-query -W -f='${Version}' "${want_pkg}" 2>/dev/null || true)"
        if [[ "${got_ver}" == "${want_ver}" ]]; then
            log_info  "  OK    ${want_pkg} = ${got_ver}"
        else
            log_error "  WRONG ${want_pkg} = '${got_ver}' (expected '${want_ver}')"
            FAILED=1
        fi
    done
fi

# --- Check 1: each binary self-reports its owning package's commit ---
log_info "--- Verifying installed mina binaries ---"
mapfile -t BINS < <(find /usr -type f -name mina 2>/dev/null | grep -vE 'completion|\.d/' || true)
if [[ ${#BINS[@]} -eq 0 ]]; then
    log_error "No mina binary found after install"
    exit 1
fi

for bin in "${BINS[@]}"; do
    owner="$(dpkg -S "${bin}" 2>/dev/null | cut -d: -f1 | head -1)"
    owner_ver="$(dpkg-query -W -f='${Version}' "${owner}" 2>/dev/null || true)"
    # Expected short commit is the tail hyphen-segment of the owning package version.
    want_short="${owner_ver##*-}"
    actual="$("${bin}" version 2>/dev/null | grep -oiE '[0-9a-f]{40}' | head -1 || true)"
    actual_short="${actual:0:${#want_short}}"
    if [[ -n "${actual}" && "${actual_short}" == "${want_short}" ]]; then
        log_info  "  OK    ${bin}  owner=${owner} (${owner_ver})  commit=${actual:0:12}"
    else
        log_error "  FAIL  ${bin}  owner=${owner} (${owner_ver})  reported='${actual:0:12}' expected~'${want_short}'"
        FAILED=1
    fi
done

if [[ "${FAILED}" -ne 0 ]]; then
    log_error "Verification FAILED for ${PACKAGE}=${VERSION} on ${CODENAME}"
    exit 1
fi
log_info "Verification PASSED for ${PACKAGE}=${VERSION} on ${CODENAME}"

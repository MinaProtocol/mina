#!/usr/bin/env bash

# configure-mirrors.sh - Configure APT to use internal mirrors/cache
#
# This script configures APT to use the internal Debian mirror and caching proxy.
# It can be sourced or called at the start of CI jobs that need apt operations
# inside Docker containers.
#
# Environment variables:
#   APT_MIRROR_URL     - URL of the direct mirror (e.g., http://deb-mirror-ingress.mirror-ingress:80)
#   APT_CACHE_PROXY    - URL of the caching proxy (e.g., http://apt-cache-ingress.mirror-ingress:3142)
#   APT_MIRROR_ENABLED - Set to "true" to enable mirror configuration
#
# Usage:
#   source ./buildkite/scripts/apt/configure-mirrors.sh
#   # or
#   ./buildkite/scripts/apt/configure-mirrors.sh

set -euo pipefail

SCRIPT_NAME="configure-apt-mirrors"

log() {
    echo "[${SCRIPT_NAME}] $*"
}

error() {
    echo "[${SCRIPT_NAME}] ERROR: $*" >&2
}

# Check if mirrors are enabled
if [ "${APT_MIRROR_ENABLED:-false}" != "true" ]; then
    log "APT mirror configuration disabled (APT_MIRROR_ENABLED != true)"
    exit 0
fi

# Detect sudo requirement
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Configure APT caching proxy
if [ -n "${APT_CACHE_PROXY:-}" ]; then
    log "Configuring APT caching proxy: ${APT_CACHE_PROXY}"

    # Create apt proxy configuration using nested brace syntax
    $SUDO mkdir -p /etc/apt/apt.conf.d
    {
        echo '// APT Caching Proxy - configured by Mina CI'
        echo "Acquire { http { Proxy \"${APT_CACHE_PROXY}\"; Timeout \"30\"; }; https { Proxy \"DIRECT\"; }; Retries \"3\"; };"
        # Bypass proxy for internal mirror (direct access within cluster)
        echo 'Acquire::http::Proxy::deb-mirror-ingress.mirror-ingress "DIRECT";'
    } | $SUDO tee /etc/apt/apt.conf.d/01proxy > /dev/null
fi

# Configure direct mirrors for specific external repositories
if [ -n "${APT_MIRROR_URL:-}" ]; then
    log "Configuring direct APT mirrors: ${APT_MIRROR_URL}"

    # Detect Ubuntu codename (focal, jammy, noble)
    UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
    log "Detected Ubuntu codename: ${UBUNTU_CODENAME}"

    # Create sources list directory if it doesn't exist
    $SUDO mkdir -p /etc/apt/sources.list.d

    # Rewrite sources.list.d files with [trusted=yes] for unsigned mirrors

    # Docker (distribution-specific)
    if [ -f /etc/apt/sources.list.d/docker.list ]; then
        log "  - Rewriting docker.list"
        echo "deb [trusted=yes] ${APT_MIRROR_URL}/docker-ce-${UBUNTU_CODENAME} ${UBUNTU_CODENAME} stable" | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi

    # PostgreSQL (distribution-specific)
    if [ -f /etc/apt/sources.list.d/pgdg.list ]; then
        log "  - Rewriting pgdg.list"
        echo "deb [trusted=yes] ${APT_MIRROR_URL}/postgresql-${UBUNTU_CODENAME} ${UBUNTU_CODENAME}-pgdg main" | $SUDO tee /etc/apt/sources.list.d/pgdg.list > /dev/null
    fi

    # Buildkite (distribution-agnostic)
    if [ -f /etc/apt/sources.list.d/buildkite-agent.list ]; then
        log "  - Rewriting buildkite-agent.list"
        echo "deb [trusted=yes] ${APT_MIRROR_URL}/buildkite stable main" | $SUDO tee /etc/apt/sources.list.d/buildkite-agent.list > /dev/null
    fi

    # Yarn (distribution-agnostic)
    if [ -f /etc/apt/sources.list.d/yarn.list ]; then
        log "  - Rewriting yarn.list"
        echo "deb [trusted=yes] ${APT_MIRROR_URL}/yarn stable main" | $SUDO tee /etc/apt/sources.list.d/yarn.list > /dev/null
    fi

    # NodeSource (distribution-agnostic)
    if [ -f /etc/apt/sources.list.d/nodesource.list ]; then
        log "  - Rewriting nodesource.list"
        echo "deb [trusted=yes] ${APT_MIRROR_URL}/nodesource nodistro main" | $SUDO tee /etc/apt/sources.list.d/nodesource.list > /dev/null
    fi
fi

log "APT mirror configuration complete"

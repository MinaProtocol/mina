#!/usr/bin/env bash
#
# Docker Buildx Multi-Architecture Builder Setup Script
#
# This script automates the creation and configuration of Docker Buildx builders
# for multi-architecture container image builds. It supports different drivers
# and can optionally install binary format emulation for cross-compilation.
#
# USAGE:
#   ./setup_buildx.sh [BUILDER_NAME]
#
# ARGUMENTS:
#   BUILDER_NAME    Optional name for the buildx builder (default: "xbuilder")
#
# ENVIRONMENT VARIABLES:
#   BUILDX_NAME       Alternative way to set builder name (default: "xbuilder")
#   DRIVER            Buildx driver to use: docker | docker-container | kubernetes (default: "docker")
#   ARCHS             Target architectures for binfmt emulation (default: "arm64")
#   INSTALL_BINFMT    Enable/disable binfmt installation: 1 | 0 (default: "1")
#
# EXAMPLES:
#   # Create default builder with docker driver
#   ./setup_buildx.sh
#
#   # Create custom builder with docker-container driver
#   DRIVER=docker-container ./setup_buildx.sh mybuilder
#
#   # Setup for multiple architectures without binfmt
#   ARCHS="arm64,amd64" INSTALL_BINFMT=0 ./setup_buildx.sh
#
# FEATURES:
#   - Validates Docker and Buildx availability
#   - Handles special case for 'docker' driver (uses default builder)
#   - Creates or reuses existing builders for other drivers
#   - Bootstraps builder instances
#   - Installs binfmt emulation for cross-architecture builds (now independent of driver)
#   - Provides summary of available builders
#
# REQUIREMENTS:
#   - Docker with Buildx plugin
#   - Privileged access (for binfmt installation)
set -euo pipefail

# Config (override via env or args)
NAME="${1:-${BUILDX_NAME:-xbuilder}}"
DRIVER="${DRIVER:-docker}"            # docker | docker-container | kubernetes
ARCHS="${ARCHS:-arm64}"               # binfmt architectures to install (comma-separated)
INSTALL_BINFMT="${INSTALL_BINFMT:-1}"

command -v docker >/dev/null || { echo "docker not found"; exit 1; }
docker buildx version >/dev/null 2>&1 || { echo "docker buildx not available"; exit 1; }

# Helper: ensure we are on a given builder
use_builder () {
  local b="$1"
  docker buildx inspect "$b" >/dev/null 2>&1 || { echo "builder '$b' not found"; return 1; }
  docker buildx use "$b"
}

# Special case: docker driver can only have ONE instance (the implicit 'default')
if [[ "$DRIVER" == "docker" ]]; then
  echo "[buildx] Using 'docker' driver -> switching to existing 'default' builder"
  if ! use_builder default; then
    # On some setups 'default' exists but isn't initialized yet; bootstrap via inspect
    docker buildx create --name default --driver docker --use || true
    docker buildx inspect default --bootstrap >/dev/null || true
    docker buildx use default
  fi
else
  # For docker-container (recommended) or other drivers: create or reuse NAME
  if docker buildx inspect "$NAME" >/dev/null 2>&1; then
    echo "[buildx] Using existing builder: $NAME"
    docker buildx use "$NAME"
  else
    # Clean any stale handle with same name (safe if it doesn't exist)
    docker buildx rm "$NAME" >/dev/null 2>&1 || true
    echo "[buildx] Creating builder: $NAME (driver: $DRIVER)"
    docker buildx create --name "$NAME" --driver "$DRIVER" --use
  fi
fi

echo "[buildx] Bootstrapping current builder"
docker buildx inspect --bootstrap >/dev/null

# Snapshot builder/driver for logs
CURRENT_BUILDER="$(docker buildx ls | awk '/\*/{gsub(/\*/, "", $1); print $1}')"
CURRENT_DRIVER="$(docker buildx inspect "$CURRENT_BUILDER" | awk -F': ' '/Driver:/ {print $2}')"

# --- NEW: Ensure binfmt (QEMU) regardless of driver when requested ---
if [[ "${INSTALL_BINFMT}" = "1" ]]; then
  # Normalize commas/spaces, split into array
  IFS=',' read -r -a _ARCHES <<<"$(echo "$ARCHS" | tr -d ' ')"

  # Map host arch to docker "platform arch" names for quick decisions
  HOST_UNAME="$(uname -m)"
  case "$HOST_UNAME" in
    x86_64)  HOST_ARCH_DOCKER="amd64"   ;;
    aarch64) HOST_ARCH_DOCKER="arm64"   ;;
    arm64)   HOST_ARCH_DOCKER="arm64"   ;;
    *)       HOST_ARCH_DOCKER="$HOST_UNAME" ;;
  esac

  echo "[binfmt] Requested arches: ${_ARCHES[*]} (host: $HOST_UNAME -> $HOST_ARCH_DOCKER)"
  echo "[binfmt] Ensuring emulators are installed (driver: $CURRENT_DRIVER)"

  # Install all requested emulators in one shot (idempotent)
  docker run --privileged --rm europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/tonistiigi/binfmt:latest --install "$(IFS=','; echo "${_ARCHES[*]}")" >/dev/null || {
    echo "[binfmt] ERROR: Failed to install binfmt for: ${_ARCHES[*]}" >&2
    exit 1
  }

  # Smoke-test non-native arches using busybox where applicable
  # Build map from arch -> platform string
  for a in "${_ARCHES[@]}"; do
    # Skip test for native arch
    if [[ "$a" == "$HOST_ARCH_DOCKER" ]]; then
      continue
    fi
    platform="linux/${a}"
    echo "[binfmt] Smoke test for ${platform} ..."
    if docker run --rm --platform="$platform" busybox uname -m 2>/dev/null | grep -qiE 'aarch64|arm64|x86_64|amd64|ppc64le|s390x|riscv64'; then
      echo "[binfmt] OK: ${platform} emulation working"
    else
      echo "[binfmt] WARNING: ${platform} smoke test did not confirm; emulation may still be fine depending on image availability" >&2
    fi
  done
else
  echo "[binfmt] Skipped (INSTALL_BINFMT=${INSTALL_BINFMT})"
fi
# --------------------------------------------------------------------

echo
echo "[summary]"
docker buildx ls

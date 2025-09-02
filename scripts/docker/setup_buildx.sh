#!/usr/bin/env bash
set -euox pipefail

# Config (override via env or args)
NAME="${1:-${BUILDX_NAME:-xbuilder}}"
DRIVER="${DRIVER:-docker}"            # docker | docker-container | kubernetes
ARCHS="${ARCHS:-arm64}"               # binfmt architectures to install
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
  use_builder default || {
    # On some setups 'default' exists but isn't initialized yet; bootstrap via inspect
    docker buildx create --name default --driver docker --use || true
    docker buildx inspect default --bootstrap >/dev/null || true
    docker buildx use default
  }
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

# Install binfmt only when using docker-container (useful for cross-building)
CURRENT_BUILDER="$(docker buildx ls | awk '/\*/{gsub(/\*/, "", $1); print $1}')"
CURRENT_DRIVER="$(docker buildx inspect "$CURRENT_BUILDER" | awk -F': ' '/Driver:/ {print $2}')"

if [[ "$INSTALL_BINFMT" = "1" && "$CURRENT_DRIVER" = "docker-container" ]]; then
  echo "[binfmt] Ensuring $ARCHS emulation is installed"
  docker run --privileged --rm tonistiigi/binfmt --install "$ARCHS" >/dev/null
fi

echo
echo "[summary]"
docker buildx ls
#!/usr/bin/env bash
set -euox pipefail

NAME="${1:-${BUILDX_NAME:-xbuilder}}"
DRIVER="${DRIVER:-docker}"
ARCHS="${ARCHS:-arm64}"
INSTALL_BINFMT="${INSTALL_BINFMT:-1}"

command -v docker >/dev/null || { echo "docker not found"; exit 1; }
docker buildx version >/dev/null 2>&1 || { echo "docker buildx not available"; exit 1; }

use_builder () {
  local b="$1"
  docker buildx inspect "$b" >/dev/null 2>&1 || { echo "builder '$b' not found"; return 1; }
  docker buildx use "$b"
}

if [[ "$DRIVER" == "docker" ]]; then
  echo "[buildx] Using 'docker' driver -> switching to existing 'default' builder"
  use_builder default || {
    docker buildx create --name default --driver docker --use || true
    docker buildx inspect default --bootstrap >/dev/null || true
    docker buildx use default
  }
else
  if docker buildx inspect "$NAME" >/dev/null 2>&1; then
    echo "[buildx] Using existing builder: $NAME"
    docker buildx use "$NAME"
  else
    docker buildx rm "$NAME" >/dev/null 2>&1 || true
    echo "[buildx] Creating builder: $NAME (driver: $DRIVER)"
    docker buildx create --name "$NAME" --driver "$DRIVER" --use
  fi
fi

echo "[buildx] Bootstrapping current builder"
docker buildx inspect --bootstrap >/dev/null

if [[ "$INSTALL_BINFMT" = "1" ]]; then
  echo "[binfmt] Ensuring $ARCHS emulation is installed"
  docker run --privileged --rm tonistiigi/binfmt --install "$ARCHS" >/dev/null
fi

echo
echo "[summary]"
docker buildx ls

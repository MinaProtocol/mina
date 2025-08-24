#!/usr/bin/env bash
set -euox pipefail

# Config (override via env or args)
NAME="${1:-${BUILDX_NAME:-xbuilder}}"
DRIVER="${DRIVER:-docker}"
ARCHS="${ARCHS:-arm64}"            # binfmt architectures to install
INSTALL_BINFMT="${INSTALL_BINFMT:-1}"

# Sanity checks
command -v docker >/dev/null || { echo "docker not found"; exit 1; }
docker buildx version >/dev/null 2>&1 || { echo "docker buildx not available"; exit 1; }

# If builder exists -> use it; else create & use it
if docker buildx inspect "$NAME" >/dev/null 2>&1; then
  echo "[buildx] Using existing builder: $NAME"
  docker buildx use "$NAME"
else
  docker buildx rm "$NAME" >/dev/null 2>&1 || true
  echo "[buildx] Creating builder: $NAME"
  docker buildx create --name "$NAME" --driver "$DRIVER" --use
fi

# Bootstrap the builder (pulls/builds the BuildKit container if needed)
echo "[buildx] Bootstrapping builder"
docker buildx inspect --bootstrap >/dev/null

# Install binfmt for cross-building (idempotent; safe to run multiple times)
if [[ "$INSTALL_BINFMT" = "1" ]]; then
  echo "[binfmt] Ensuring $ARCHS emulation is installed"
  docker run --privileged --rm tonistiigi/binfmt --install "$ARCHS" >/dev/null
fi

echo
echo "[summary]"
docker buildx ls

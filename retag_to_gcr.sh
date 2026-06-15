#!/usr/bin/env bash
set -euo pipefail

SRC_REPO="europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo"
DST_REPO="gcr.io/o1labs-192920"

VERSION="4.0.0-rc1-mesa-mut"
SHA="97171f5"
SUFFIX="mesa-mut-generic"

CODENAMES=(bullseye jammy bookworm noble focal)
SERVICES=(mina-daemon mina-rosetta)

for service in "${SERVICES[@]}"; do
  for codename in "${CODENAMES[@]}"; do
    tag="${VERSION}-${SHA}-${codename}-${SUFFIX}"
    src="${SRC_REPO}/${service}:${tag}"
    dst="${DST_REPO}/${service}:${tag}"

    echo "==> [$service/$codename] pulling  $src"
    docker pull "$src"

    echo "==> [$service/$codename] tagging  -> $dst"
    docker tag "$src" "$dst"

    echo "==> [$service/$codename] pushing  $dst"
    docker push "$dst"

    echo "==> [$service/$codename] done"
    echo
  done
done

echo "All images retagged and pushed to ${DST_REPO}."

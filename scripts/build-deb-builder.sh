#!/bin/bash

set -eou pipefail

BRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)
DOCKER_BRANCH=$(echo "${BRANCH}" | sed 's!/!-!; s!_!-!g')
CODENAME="${CODENAME:=buster}"
TAG="${CODENAME}-${DOCKER_BRANCH}"
echo "--- Building and pushing gcr.io/o1labs-192920/mina-deb-builder:${TAG}"

time cat dockerfiles/Dockerfile-deb-builder | docker build \
  --target builder \
  --build-arg CODENAME=${CODENAME} \
  --build-arg OPAM_BRANCH=${BRANCH} \
  --build-arg MINA_BRANCH=$(git rev-parse HEAD) \
  -t gcr.io/o1labs-192920/mina-deb-builder:${TAG} -

docker push gcr.io/o1labs-192920/mina-deb-builder:${TAG}

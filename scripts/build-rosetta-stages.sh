#!/bin/bash

set -eou pipefail

GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)
TAG=$(echo ${GITBRANCH} | sed 's!/!-!; s!_!-!g')
time cat dockerfiles/Dockerfile-rosetta | docker build \
  --target build-deps \
  -t gcr.io/o1labs-192920/coda-rosetta-build-deps:$TAG -
docker push gcr.io/o1labs-192920/coda-rosetta-build-deps:$TAG
time cat dockerfiles/Dockerfile-rosetta | docker build \
  --target opam-deps \
   -t gcr.io/o1labs-192920/coda-rosetta-opam-deps:$TAG \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-build-deps:$TAG \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -
docker push gcr.io/o1labs-192920/coda-rosetta-opam-deps:$TAG
time cat dockerfiles/Dockerfile-rosetta | docker build \
  --target builder \
  -t gcr.io/o1labs-192920/coda-rosetta-builder:$TAG \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-opam-deps:$TAG \
  --build-arg "DUNE_PROFILE=dev" \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -
docker push gcr.io/o1labs-192920/coda-rosetta-builder:dev-$TAG
time cat dockerfiles/Dockerfile-rosetta | docker build \
  --target production \
  -t gcr.io/o1labs-192920/coda-rosetta:$TAG \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-builder:$TAG \
  --build-arg "DUNE_PROFILE=dev" \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -
docker push gcr.io/o1labs-192920/coda-rosetta:dev-$TAG

# Also build with the default dune profile
time cat dockerfiles/Dockerfile-rosetta | docker build \
  --target builder \
  -t gcr.io/o1labs-192920/coda-rosetta-builder:$TAG \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-opam-deps:$TAG \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -
docker push gcr.io/o1labs-192920/coda-rosetta-builder:medium-curves-$TAG
time cat dockerfiles/Dockerfile-rosetta | docker build \
  --target production \
  -t gcr.io/o1labs-192920/coda-rosetta:$TAG \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-builder:$TAG \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -
docker push gcr.io/o1labs-192920/coda-rosetta:medium-curves-$TAG

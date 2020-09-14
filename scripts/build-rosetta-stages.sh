#!/bin/bash

set -eou pipefail

GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)
TAG=$(echo ${GITBRANCH} | sed 's!/!-!; s!_!-!g')

cat dockerfiles/Dockerfile-rosetta | docker build \
  --force-rm \
  --target build-deps \
  -t gcr.io/o1labs-192920/coda-rosetta-build-deps:$TAG -

cat dockerfiles/Dockerfile-rosetta | docker build \
  --force-rm \
  --target opam-deps \
   -t gcr.io/o1labs-192920/coda-rosetta-opam-deps:$TAG \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-build-deps:$TAG \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -

# Build with the dev profile
cat dockerfiles/Dockerfile-rosetta | docker build \
  --force-rm \
  --target builder \
  -t gcr.io/o1labs-192920/coda-rosetta-builder:dev-$TAG \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-opam-deps:$TAG \
  --build-arg "DUNE_PROFILE=dev" \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -
cat dockerfiles/Dockerfile-rosetta | docker build \
  --force-rm \
  --target production \
  -t gcr.io/o1labs-192920/coda-rosetta:dev-$TAG \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-builder:dev-$TAG \
  --build-arg "DUNE_PROFILE=dev" \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -

# Also build with the default dune profile
cat dockerfiles/Dockerfile-rosetta | docker build \
  --force-rm \
  --target builder \
  -t gcr.io/o1labs-192920/coda-rosetta-builder:medium-curves-$TAG \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-opam-deps:$TAG \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -
cat dockerfiles/Dockerfile-rosetta | docker build \
  --force-rm \
  --target production \
  -t gcr.io/o1labs-192920/coda-rosetta:medium-curves-$TAG \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-builder:medium-curves-$TAG \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -


docker push gcr.io/o1labs-192920/coda-rosetta-build-deps:$TAG
docker push gcr.io/o1labs-192920/coda-rosetta-opam-deps:$TAG
# docker push gcr.io/o1labs-192920/coda-rosetta-builder:medium-curves-$TAG
# docker push gcr.io/o1labs-192920/coda-rosetta-builder:dev-$TAG
docker push gcr.io/o1labs-192920/coda-rosetta:dev-$TAG
docker push gcr.io/o1labs-192920/coda-rosetta:medium-curves-$TAG

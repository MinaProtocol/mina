cat dockerfiles/Dockerfile-rosetta | docker build \
  --target production \
  -t gcr.io/o1labs-192920/coda-rosetta:latest \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-opam-deps:latest \
  --build-arg "CODA_BRANCH=rosetta/dockerfile" -

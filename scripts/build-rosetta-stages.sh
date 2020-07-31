GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)
time cat dockerfiles/Dockerfile-rosetta | docker build \
  --target build-deps \
  -t gcr.io/o1labs-192920/coda-rosetta-build-deps:latest -
time cat dockerfiles/Dockerfile-rosetta | docker build \
  --target opam-deps \
   -t gcr.io/o1labs-192920/coda-rosetta-opam-deps:latest \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-build-deps:latest \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -
time cat dockerfiles/Dockerfile-rosetta | docker build \
  --target builder \
  -t gcr.io/o1labs-192920/coda-rosetta-builder:latest \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-opam-deps:latest \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -
time cat dockerfiles/Dockerfile-rosetta | docker build \
  --target production \
  -t gcr.io/o1labs-192920/coda-rosetta:latest \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-builder:latest \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -

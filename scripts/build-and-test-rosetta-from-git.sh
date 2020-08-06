GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)
TAG=$(echo ${GITBRANCH} | sed 's!/!-!; s!_!-!g')

docker pull gcr.io/o1labs-192920/coda-rosetta-opam-deps:${TAG}

cat dockerfiles/Dockerfile-rosetta | docker build \
  --target production \
  -t gcr.io/o1labs-192920/coda-rosetta:${TAG} \
  --cache-from gcr.io/o1labs-192920/coda-rosetta-opam-deps:${TAG} \
  --build-arg "DUNE_PROFILE=dev" \
  --build-arg "CODA_BRANCH=${GITBRANCH}" -

docker run -it --entrypoint=./docker-test-start.sh gcr.io/o1labs-192920/coda-rosetta:${TAG}

[[ $? -eq 0 ]] && docker push gcr.io/o1labs-192920/coda-rosetta:${TAG} || echo "Tests failed, not pushing"

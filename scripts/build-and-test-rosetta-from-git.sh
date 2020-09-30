GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)
TAG=$(echo ${GITBRANCH} | sed 's!/!-!; s!_!-!g')

docker pull gcr.io/o1labs-192920/mina-rosetta-opam-deps:${TAG}

cat dockerfiles/Dockerfile-rosetta | docker build \
  --target production \
  -t gcr.io/o1labs-192920/mina-rosetta:${TAG} \
  --no-cache \
  --build-arg "DUNE_PROFILE=dev" \
  --build-arg "MINA_BRANCH=${GITBRANCH}" -
  #--cache-from gcr.io/o1labs-192920/mina-rosetta-opam-deps:${TAG} \

docker run -it --entrypoint=./docker-test-start.sh gcr.io/o1labs-192920/mina-rosetta:${TAG}

[[ $? -eq 0 ]] && docker push gcr.io/o1labs-192920/mina-rosetta:${TAG} || echo "Tests failed, not pushing"

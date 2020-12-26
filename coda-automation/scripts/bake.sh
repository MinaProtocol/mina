#!/bin/bash

# Set defaults before parsing args
TESTNET=turbo-pickles
DOCKER_TAG=0.0.16-beta7-develop
AUTOMATION_PATHSPEC=$(git log master -1 --pretty=format:%H)
CONFIG_FILE=/root/daemon.json
CLOUD=false

# arguments are
# --docker-tag=, --testnet=, --config-file=, --automation-commit=, and --cloud=
while [ $# -gt 0 ]; do
  case "$1" in
    --testnet=*)
      TESTNET="${1#*=}"
      ;;
    --docker-tag=*)
      DOCKER_TAG="${1#*=}"
      ;;
    --automation-commit=*)
      AUTOMATION_PATHSPEC="${1#*=}"
      ;;
    --config-file=*)
      CONFIG_FILE="${1#*=}"
      ;;
    --cloud=*)
      CLOUD="${1#*=}"
      ;;
  esac
  shift
done

echo Testnet is ${TESTNET}
echo Initial Docker Image is codaprotocol/coda-daemon:${DOCKER_TAG}
echo Coda Automation Pathspec is ${AUTOMATION_PATHSPEC}
echo Config File Path is ${CONFIG_FILE}

first7=$(echo ${AUTOMATION_PATHSPEC} | cut -c1-7)

hub_baked_tag="codaprotocol/coda-daemon-baked:${DOCKER_TAG}-${TESTNET}-${first7}"
gcr_baked_tag="gcr.io/o1labs-192920/coda-daemon-baked:${DOCKER_TAG}-${TESTNET}-${first7}"

docker_tag_exists() {
  curl --silent -f -lSL "https://index.docker.io/v1/repositories/codaprotocol/coda-daemon/tags/${DOCKER_TAG}" > /dev/null
}

if [[ $CLOUD == true ]]
then
  echo Building $gcr_baked_tag in the cloud

  cd ./bake
  gcloud builds submit --config=cloudbuild.yaml \
  --substitutions=_BAKE_VERSION="$DOCKER_TAG",_COMMIT_HASH="$AUTOMATION_PATHSPEC",_TESTNET_NAME="$TESTNET",_CONFIG_FILE="$CONFIG_FILE",_GCR_BAKED_TAG="$gcr_baked_tag" .

  exit 0
fi

for i in $(seq 60); do
  docker_tag_exists && break
  [ "$i" != 30 ] || (echo "expected image never appeared in docker registry" && exit 1)
  sleep 30
done

cat bake/Dockerfile | docker build \
  -t "${hub_baked_tag}" \
  --build-arg "BAKE_VERSION=${DOCKER_TAG}" \
  --build-arg "COMMIT_HASH=${AUTOMATION_PATHSPEC}" \
  --build-arg "TESTNET_NAME=${TESTNET}" \
  --build-arg "CONFIG_FILE=${CONFIG_FILE}" -

docker push "$hub_baked_tag"
docker tag "$hub_baked_tag" "$gcr_baked_tag"
docker push "$gcr_baked_tag"
echo "Built + Pushed Image: ${hub_baked_tag}"


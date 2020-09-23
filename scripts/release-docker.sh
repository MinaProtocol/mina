#!/bin/bash

# Author's Note: Because the structure of this repo is inconsistent (Dockerfiles and build contexts placed willy-nilly)
# we have to trustlist and configure image builds individually because each one is going to be slightly different. 
# This is needed as opposed to trusting the structure of the each project to be consistent for every deployable. 

set -eo pipefail
set +x

CLEAR='\033[0m'
RED='\033[0;31m'
# Array of valid service names
VALID_SERVICES=('coda-daemon' 'coda-daemon-puppeteered' 'bot' 'coda-demo' 'coda-rosetta', 'leaderboard')

function usage() {
  if [ -n "$1" ]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 [-s service-to-release] [-v service-version]"
  echo "  -s, --service             The Service being released to Dockerhub"
  echo "  -v, --version             The version to be used in the docker image tag"
  echo ""
  echo "Example: $0 --service faucet --version v0.1.0"
  echo "Valid Services: ${VALID_SERVICES[*]}"
  exit 1
}

while [[ "$#" -gt 0 ]]; do case $1 in
  -s|--service) SERVICE="$2"; shift;;
  -v|--version) VERSION="$2"; shift;;
  --extra-args) EXTRA="$2"; shift;;
  --no-upload) NOUPLOAD=1;shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

# Debug prints for visability
echo 'service="'$SERVICE'" version="'$VERSION'"'
echo $EXTRA

# Verify Required Parameters are Present
if [ -z "$SERVICE" ]; then usage "Service is not set!"; fi;
if [ -z "$VERSION" ]; then usage "Version is not set!"; fi;
if [ -z "$EXTRA" ]; then EXTRA=""; fi;
if [ $(echo ${VALID_SERVICES[@]} | grep -o "$SERVICE" - | wc -w) -eq 0 ]; then usage "Invalid service!"; fi

case $SERVICE in
bot)
  DOCKERFILE_PATH="frontend/bot/Dockerfile"
  DOCKER_CONTEXT="frontend/bot"
  ;;
coda-daemon)
  DOCKERFILE_PATH="dockerfiles/Dockerfile-coda-daemon"
  ;;
coda-daemon-puppeteered)
  DOCKERFILE_PATH="dockerfiles/Dockerfile-coda-daemon-puppeteered"
  ;;
coda-demo)
  DOCKERFILE_PATH="dockerfiles/Dockerfile-coda-demo"
  ;;
coda-rosetta)
  DOCKERFILE_PATH="dockerfiles/Dockerfile-rosetta"
  ;;
leaderboard)
  DOCKERFILE_PATH="frontend/leaderboard/Dockerfile"
  DOCKER_CONTEXT="frontend/leaderboard"
  ;;
*)
esac

# If DOCKER_CONTEXT is not specified, assume none and just pipe the dockerfile into docker build
if [ -z "$DOCKER_CONTEXT" ]; then
cat $DOCKERFILE_PATH | docker build $EXTRA -t codaprotocol/$SERVICE:$VERSION -
else
docker build $EXTRA $DOCKER_CONTEXT -t codaprotocol/$SERVICE:$VERSION -f $DOCKERFILE_PATH
fi

if [ -z "$NOUPLOAD" ] || [ "$NOUPLOAD" -eq 0 ]; then docker push codaprotocol/$SERVICE:$VERSION; fi;

#!/usr/bin/env bash

# end to end test for rosetta connectivity with given network 
set -x
CLEAR='\033[0m'
RED='\033[0;31m'

NETWORK=devnet
TIMEOUT=900

while [[ "$#" -gt 0 ]]; do case $1 in
  -n|--network) NETWORK="$2"; shift;;
  -t|--tag) TAG="$2"; shift;;
  --timeout) TIMEOUT="$2"; shift;;
  -h|--help) usage; exit 0;;
  *) echo "Unknown parameter passed: $1"; usage; exit 1;;
esac; shift; done


function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 [-t docker-tag] [-n network]"
  echo "  -t, --version             The version to be used in the docker image tag"
  echo "  -n, --network             The network configuration to use (devnet or mainnet). Default=$NETWORK"
  echo "  --timeout                 The timeout duration in seconds. Default=$TIMEOUT"
  echo "  -h, --help                Show help"
  echo ""
  echo "Example: $0 --network devnet --tag 3.0.3-bullseye-berkeley "
  echo ""
  echo "Warning:"
  echo "Please execute this script from the root of the mina repository."
  echo ""
}   

if [[ -z "$TAG" ]]; then usage "Docker tag is not set!"; usage; exit 1; fi;

container_id=$(docker run -p 3087:3087 -d --env MINA_NETWORK=$NETWORK gcr.io/o1labs-192920/mina-rosetta:$TAG-$NETWORK )

stop_docker() {
    { docker stop "$container_id" ; docker rm "$container_id" ; } || true
}

trap stop_docker ERR

# Wait for the container to start
sleep 5
#run sanity test
./scripts/tests/rosetta-sanity.sh --address "http://localhost:3087" --network $NETWORK --wait-for-sync --timeout $TIMEOUT

stop_docker
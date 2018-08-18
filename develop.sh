#!/bin/bash

set -u

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <restart|no-restart>"
  exit 1
fi

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
IMAGE='nanotest:latest'

echo "Working Directory: ${SCRIPTPATH}"

# Use :delegated option to improve volume mount performance in osx
# https://docs.docker.com/docker-for-mac/osxfs-caching/
VOLUME_OPTION=''
if [[ $(uname) == 'Darwin' ]]; then 
    VOLUME_OPTION=':delegated'
fi

# FIXME: Used named containers, don't rely on image name
if [[ $1 == "restart" ]]; then
  if $(docker ps | grep -q ${IMAGE}); then
    echo "Stopping developer container"
    docker kill $(docker ps | grep ${IMAGE} | head | awk '{ print $1 }')
  fi
 
  echo "Starting developer container"
  NAME=$(docker run \
        -v ${SCRIPTPATH}:/home/opam/app${VOLUME_OPTION} \
        --detach \
        --interactive \
        --tty \
        ${IMAGE})
else
  NAME=$(docker ps | grep ${IMAGE} | head | awk '{ print $1 }')
fi

sleep 1
echo "Starting dune build"
./scripts/run-in-docker dune build

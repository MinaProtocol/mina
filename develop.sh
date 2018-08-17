#!/bin/bash

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <restart|no-restart>"
  exit 1
fi

echo "Starting developer docker container"

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
IMG=nanotest:latest

# FIXME: Used named images, don't rely on image name

if [[ $1 == "restart" ]]; then
  if $(docker ps | grep -q $IMG); then
    echo "Stopping previous image"
    docker kill $(docker ps | grep $IMG | head | awk '{ print $1 }')
  fi
  NAME=$(docker run -v $SCRIPTPATH:/home/opam/app -d -ti $IMG)
else
  NAME=$(docker ps | grep $IMG | head | awk '{ print $1 }')
fi

run-in-docker dune build

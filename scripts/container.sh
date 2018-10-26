#!/bin/bash

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <restart|no-restart>"
  exit 1
fi

echo "Starting developer docker container"

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
IMG=codabuilder:latest

MYUID=$(id -u)
MYGID=$(id -g)

DOCKERNAME="codabuilder-$MYUID"

if [[ $1 == "restart" ]]; then
  if $(docker ps | grep -q $IMG); then
    echo "Stopping previous dev container"
    docker ps -q --filter "name=$DOCKERNAME" | grep -q . && docker stop $DOCKERNAME > /dev/null
  fi

    # Delete prior image if it's been stopped, but not deleted
    docker rm -fv $DOCKERNAME > /dev/null
    echo "Starting new dev container - $DOCKERNAME"
    NAME=$(docker run \
      --volume $SCRIPTPATH/..:/home/opam/app \
      --user $MYUID:$MYGID \
      --name $DOCKERNAME \
      --detach \
      --tty \
      --interactive \
      $IMG \
      sleep infinity)
else
  NAME=$(docker ps -q --filter "name=$DOCKERNAME")
fi

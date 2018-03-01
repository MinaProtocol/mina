#!/bin/bash

set -e

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

$SCRIPTPATH/rebuild-docker.sh $1

img=$1:latest

docker build -t $img .
docker tag $img localhost:5000/$img
docker push localhost:5000/$img

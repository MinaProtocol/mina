#!/bin/bash

set -e

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

$SCRIPTPATH/scripts/rebuild-docker.sh $1 $2

img=$1:latest

docker tag $img localhost:5000/$img
docker push localhost:5000/$img


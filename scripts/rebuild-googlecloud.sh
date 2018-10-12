#!/bin/bash

set -e

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

$SCRIPTPATH/rebuild-docker.sh $1 $2 $3

if [[ -z $3 ]]; then
  img=$1:latest
else
  img=$1:$3
fi
project=$(gcloud config get-value project)

docker tag $img gcr.io/$project/$img
gcloud docker -- push gcr.io/$project/$img


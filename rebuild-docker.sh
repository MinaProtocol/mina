#!/bin/bash

# Wrapper script for container builds

set -e

if [ ! $# -eq 1 ] && [ ! $# -eq 2 ] && [ ! $# -eq 3 ];
then
  echo "Usage: $0 image-name [Dockerfile] [tag]"
  exit 1
fi

imagename=$1:latest
dockerfile=${2:-Dockerfile}

echo "Building docker container named ${imagename} using ${dockerfile}."
docker build --file $dockerfile --tag $imagename .

# Retag with new image name
if [[ ! -z $3 ]]; then
  echo "Retagging as ${imagename}:$3"
  docker tag $imagename $imagename:$3
fi
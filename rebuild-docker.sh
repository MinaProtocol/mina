#!/bin/bash

set -e

if [ ! $# -eq 1 ] && [ ! $# -eq 2 ] && [ ! $# -eq 3 ];
then
  echo "Usage: $0 image-name [Dockerfile] [tag]"
  exit 1
fi

img=$1:latest
file=${2:-Dockerfile}

docker build -f $file -t $img .
if [[ ! -z $3 ]]; then
  docker tag $img $1:$3
fi


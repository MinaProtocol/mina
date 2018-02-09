#!/bin/bash

set -e

if [ ! $# -eq 1 ] && [ ! $# -eq 2 ];
then
  echo "Usage: $0 image-name"
  exit 1
fi

img=$1:latest
file=${2:-Dockerfile}

docker build -f $file -t $img .


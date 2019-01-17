#!/bin/bash

set -e

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 image-name"
  exit 1
fi

docker build -t $1:latest .


#!/bin/bash
set -eo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <codename>"
  exit 1
fi

CODENAME=$1
BUILD_FOLDER=_build

if [ -d "$BUILD_FOLDER" ]; then
  cd "$BUILD_FOLDER"
else
  echo "$BUILD_FOLDER does not exist. Are you sure you run build before running upload deb"
  exit 1
fi

for entry in mina-*.deb; do
  ./cache-artifact.sh $entry $CODENAME/debs
done
#!/bin/bash
set -e

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 newtag"
  exit
fi

filenames="
  $SCRIPTPATH/../dockerfiles/Dockerfile
  $SCRIPTPATH/../.circleci/config.yml.jinja
"

for filename in $filenames
do
  echo "Updating $filename with new toolchain reference: $1"
  sed -i "s/toolchain-.*/toolchain-$1/g" $filename
done

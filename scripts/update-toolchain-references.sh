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
  $SCRIPTPATH/../README-dev.md
"

for filename in $filenames ; do
    echo "Updating $filename with new toolchain reference: $1"
    sed -i "s/toolchain-[0-9a-f]\+[^\`]\?/toolchain-$1/g" $filename
done

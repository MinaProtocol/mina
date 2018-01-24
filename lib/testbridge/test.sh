#!/bin/bash


if [ $# -eq 0 ]
then
  echo "missing argument: test directory"
  exit 1
fi

test=$1

set -e

cd bridge
jbuilder build
opam upgrade testbridge

cd ..

cd $test/client
jbuilder build

cd ../host
jbuilder build
_build/install/default/bin/main \
  -container-count 2 \
  -containers-per-machine 2

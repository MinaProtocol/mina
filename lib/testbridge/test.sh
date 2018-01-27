#!/bin/bash

#example: from lib/testbridge, 
#./test.sh ./tests/echo/host ../../_build/install/default/bin/echo_host 


if [ ! $# -eq 2 ]
then
  echo "missing argument"
  exit 1
fi

loc=$1
bin=$2

set -e

cd ../../
jbuilder build

cd lib/testbridge/$loc

../../../$bin \
  -container-count 2 \
  -containers-per-machine 2



#!/bin/bash

#example: from lib/testbridge, 
#./test.sh ./tests/echo/host ../../_build/install/default/bin/echo_host localhost:5000/testbridge:latest
#./test.sh ./tests/nanobit/host/ ../../_build/install/default/bin/nanobit_host gcr.io/$(gcloud config get-value project)/testbridge-nanobit:latest

if [ ! $# -eq 2 ] && [ ! $# -eq 3 ];
then
  echo "missing argument"
  exit 1
fi

if [ $# -eq 2 ]
then
  host=gcr.io/$(gcloud config get-value project)/testbridge:latest
else
  host=$3
fi

loc=$1
bin=$2

set -e

cd ../../
dune build

cd lib/testbridge/$loc

../../../$bin \
  -container-count 4 \
  -containers-per-machine 2 \
  -image-host $host

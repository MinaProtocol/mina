#!/bin/bash

#example: from lib/nanobit_testbridge, 
#./run.sh swim_example/ ../../_build/install/default/bin/nanobit_testbridge_swim_example 4

if [ ! $# -eq 3 ] && [ ! $# -eq 4 ];
then
  echo "missing argument"
  exit 1
fi

if ! [ $# -eq 4 ]
then
  host=gcr.io/$(gcloud config get-value project)/testbridge-nanobit:latest
else
  host=$4
fi

loc=$1
bin=$2
containers=$3

set -e

cd ../../
jbuilder build

cd lib/nanobit_testbridge/$loc

../$bin \
  -container-count $containers \
  -containers-per-machine 2 \
  -image-host $host

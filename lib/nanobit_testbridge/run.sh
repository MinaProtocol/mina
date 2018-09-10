#!/bin/bash

#example: from lib/nanobit_testbridge, 
#./run.sh swim_example/ ../../_build/install/default/bin/nanobit_testbridge_swim_example 4
#./run.sh swim_consistency/ ../../_build/install/default/bin/nanobit_testbridge_swim_consistency 4
#./run.sh recent_lca/ ../../_build/install/default/bin/nanobit_testbridge_recent_lca 4

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPTPATH

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
dune build

cd lib/nanobit_testbridge/$loc

PATH=$PATH:~/google-cloud-sdk/bin ../$bin \
  -container-count $containers \
  -containers-per-machine 2 \
  -image-host $host

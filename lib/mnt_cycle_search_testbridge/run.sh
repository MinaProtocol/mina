#!/bin/bash

#example: from lib/nanobit_testbridge, 
#./run.sh search/ ../../_build/install/default/bin/mnt_cycle_search_testbridge_searcher 4

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd $SCRIPTPATH

if [ ! $# -eq 3 ] && [ ! $# -eq 4 ];
then
  echo "missing argument"
  exit 1
fi

if ! [ $# -eq 4 ]
then
  host=gcr.io/$(gcloud config get-value project)/mnt-cycle-search-testbridge:latest
else
  host=$4
fi

loc=$1
bin=$2
containers=$3

set -e

cd ../../
jbuilder build

cd lib/mnt_cycle_search_testbridge/$loc

PATH=$PATH:~/google-cloud-sdk/bin ../$bin \
  -container-count $containers \
  -containers-per-machine 2 \
  -image-host $host

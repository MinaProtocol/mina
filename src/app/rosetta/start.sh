#!/bin/bash

set -eou pipefail

function cleanup
{
  echo "Cleaning up backgrounded processes"
  kill $(ps aux | egrep '_build.*archive\.exe' | grep -v grep | awk '{ print $2 }')
  kill $(ps aux | egrep '_build.*coda\.exe' | grep -v grep | awk '{ print $2 }')
  kill $(ps aux | egrep '_build.*rosetta\.exe' | grep -v grep | awk '{ print $2 }')
  exit
}

trap cleanup TERM
trap cleanup INT

PG_CONN=postgres://$USER:$USER@localhost:5432/archiver

# rebuild
pushd ../../../
PATH=/usr/local/bin:$PATH dune b src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe src/app/cli/src/coda.exe src/app/archive/archive.exe src/app/rosetta/rosetta.exe
popd

# make genesis
./make-runtime-genesis.sh

# archive
../../../_build/default/src/app/archive/archive.exe \
  -postgres-uri $PG_CONN \
  -server-port 3086 &

# wait for it to settle
sleep 5

# demo node
./run-demo.sh \
    -archive-address 3086 -log-level debug &

# rosetta
../../../_build/default/src/app/rosetta/rosetta.exe \
  -archive-uri $PG_CONN \
  -graphql-uri https://localhost:3085/graphql \
  -port 3087 &

# wait for a signal
sleep infinity


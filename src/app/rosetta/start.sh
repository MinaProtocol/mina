#!/bin/bash

set -eou pipefail

function cleanup
{
  echo "Killing archive.exe"
  kill $(ps aux | egrep '_build/default/src/app/.*archive.exe' | grep -v grep | awk '{ print $2 }') || true
  echo "Killing coda.exe"
  kill $(ps aux | egrep '_build/default/src/app/.*coda.exe'    | grep -v grep | awk '{ print $2 }') || true
  echo "Killing rosetta.exe"
  kill $(ps aux | egrep '_build/default/src/app/rosetta'       | grep -v grep | awk '{ print $2 }') || true
  exit
}

trap cleanup TERM
trap cleanup INT

PG_CONN=postgres://$USER:$USER@localhost:5432/archiver

# rebuild
pushd ../../../
PATH=/usr/local/bin:$PATH dune b src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe src/app/cli/src/coda.exe src/app/archive/archive.exe src/app/rosetta/rosetta.exe
popd

# make genesis (synchronously)
./make-runtime-genesis.sh

# archive
../../../_build/default/src/app/archive/archive.exe run \
  -postgres-uri $PG_CONN \
  -server-port 3086 &

# wait for it to settle
sleep 3

# demo node
./run-demo.sh \
    -external-ip 127.0.0.1 \
    -archive-address 3086 \
    -log-level debug &

# wait for it to settle
sleep 3

# rosetta
../../../_build/default/src/app/rosetta/rosetta.exe \
  -archive-uri $PG_CONN \
  -graphql-uri http://localhost:3085/graphql \
  -log-level debug \
  -port 3087 &

# wait for a signal
sleep infinity


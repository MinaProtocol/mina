#!/bin/bash

set -eou pipefail

function cleanup
{
  CODE=${1:-0}
  echo "Killing archive.exe"
  kill $(ps aux | egrep '_build/default/src/app/.*archive.exe' | grep -v grep | awk '{ print $2 }') || true
  echo "Killing coda.exe"
  kill $(ps aux | egrep '_build/default/src/app/.*coda.exe'    | grep -v grep | awk '{ print $2 }') || true
  echo "Killing agent.exe"
  kill $(ps aux | egrep '_build/default/src/app/rosetta/test-agent/agent.exe'       | grep -v grep | awk '{ print $2 }') || true
  echo "Killing rosetta.exe"
  kill $(ps aux | egrep '_build/default/src/app/rosetta'       | grep -v grep | awk '{ print $2 }') || true
  exit $CODE
}

trap cleanup TERM
trap cleanup INT

PG_CONN=postgres://$USER:$USER@localhost:5432/archiver

# rebuild
pushd ../../../
PATH=/usr/local/bin:$PATH dune b src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe src/app/cli/src/coda.exe src/app/archive/archive.exe src/app/rosetta/rosetta.exe src/app/rosetta/test-agent/agent.exe
popd

# make genesis (synchronously)
./make-runtime-genesis.sh

# drop tables and recreate
psql -d archiver < drop_tables.sql
psql -d archiver < create_schema.sql

# archive
../../../_build/default/src/app/archive/archive.exe run \
  -postgres-uri $PG_CONN \
  -log-json \
  -server-port 3086 &

# wait for it to settle
sleep 3

# demo node
./run-demo.sh \
    -external-ip 127.0.0.1 \
    -archive-address 3086 \
    -log-json \
    -log-level debug &

# wait for it to settle
sleep 3

# rosetta
../../../_build/default/src/app/rosetta/rosetta.exe \
  -archive-uri $PG_CONN \
  -graphql-uri http://localhost:3085/graphql \
  -log-level debug \
  -log-json \
  -port 3087 &

# wait for it to settle
sleep 3

ARG=${1:-NONE}
if [[ "$ARG" == "CURL" ]]; then
  echo "Running for curl mode, no agent present"
  sleep infinity
else
  # test agent
  ../../../_build/default/src/app/rosetta/test-agent/agent.exe \
    -graphql-uri http://localhost:3085/graphql \
    -rosetta-uri http://localhost:3087/ \
    -log-level Trace \
    -log-json &

  # wait for test agent to exit (asynchronously)
  AGENT_PID=$!
  while $(kill -0 $AGENT_PID 2> /dev/null); do
    sleep 2
  done
  set +e
  wait $AGENT_PID
  AGENT_STATUS=$?
  set -e
  echo "Test finished with code $AGENT_STATUS"

  # then cleanup and forward the status
  cleanup $AGENT_STATUS
fi


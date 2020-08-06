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

# Start postgres
pg_ctlcluster 11 main start

# wait for it to settle
sleep 3

# archive
/coda-bin/archive/archive.exe run \
  -postgres-uri $PG_CONN \
  -log-json \
  -server-port 3086 &

# wait for it to settle
sleep 3

# Setup and run demo-node
PK=${PK:-B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g}
genesis_time=$(date -d '2019-01-30 20:00:00.000000Z' '+%s')
now_time=$(date +%s)
export CODA_TIME_OFFSET=$(( $now_time - $genesis_time ))
export CODA_PRIVKEY_PASS=""
export CODA_LIBP2P_HELPER_PATH=/coda-bin/libp2p_helper
CODA_CONFIG_DIR=/root/.coda-config

# CODA_CONFIG_DIR is exposed by the dockerfile and contains demo mode essentials
/coda-bin/cli/src/coda.exe daemon \
  -seed \
  -demo-mode \
  -block-producer-key "$CODA_CONFIG_DIR/wallets/store/$PK" \
  -run-snark-worker $PK \
  -config-file "$CODA_CONFIG_DIR/daemon.json" \
  -config-dir "$CODA_CONFIG_DIR" \
  -insecure-rest-server \
  -external-ip 127.0.0.1 \
  -archive-address 3086 \
  -log-json \
  -log-level debug &

# wait for it to settle
sleep 3

# rosetta
/coda-bin/rosetta/rosetta.exe \
  -archive-uri $PG_CONN \
  -graphql-uri http://localhost:3085/graphql \
  -log-level debug \
  -log-json \
  -port 3087 &

# wait for it to settle
sleep 3

# test agent
/coda-bin/rosetta/test-agent/agent.exe \
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


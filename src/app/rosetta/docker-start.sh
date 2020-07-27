#!/bin/bash

set -eou pipefail

function cleanup
{
  echo "Killing archive.exe"
  kill $(ps aux | egrep '/coda-bin/.*archive.exe' | grep -v grep | awk '{ print $2 }') || true
  echo "Killing coda.exe"
  kill $(ps aux | egrep '/coda-bin/.*coda.exe'    | grep -v grep | awk '{ print $2 }') || true
  echo "Killing rosetta.exe"
  kill $(ps aux | egrep '/coda-bin/rosetta'       | grep -v grep | awk '{ print $2 }') || true
  echo "Stopping postgres"
  pg_ctlcluster 11 main stop
  exit
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
  -server-port 3086 &

# wait for it to settle
sleep 3

genesis_time=$(date -d '2019-01-30 20:00:00.000000Z' '+%s')
now_time=$(date '+%s')

export CODA_PRIVKEY_PASS=""
export CODA_TIMEOFFSET=$(( $now_time - $genesis_time ))
export CODA_CONFIG_FILE=${CODA_CONFIG_FILE:=/data/config.json}
export PEER_ID=${PEER_ID:=$PEER_ID}
DEFAULT_FLAGS="-generate-genesis-proof true -peer ${PEER_ID} -archive-address 0.0.0.0:3086 -insecure-rest-server -log-level debug"
export CODA_FLAGS=${CODA_FLAGS:=$DEFAULT_FLAGS}
export CODA_LIBP2P_HELPER_PATH=/coda-bin/libp2p_helper
PK=${CODA_PK:=ZsMSUuKL9zLAF7sMn951oakTFRCCDw9rDfJgqJ55VMtPXaPa5vPwntQRFJzsHyeh8R8}

echo "CODA Flags: $CODA_FLAGS -config-file ${CODA_CONFIG_FILE}"

# Daemon w/ mounted config file, initial file is phase 3 config.json
/coda-bin/cli/src/coda.exe daemon \
    -config-file ${CODA_CONFIG_FILE} \
    ${CODA_FLAGS} &

# wait for it to settle
sleep 3

# rosetta
/coda-bin/rosetta/rosetta.exe \
  -archive-uri $PG_CONN \
  -graphql-uri http://localhost:3085/graphql \
  -log-level debug \
  -port 3087 &

# wait for a signal
sleep infinity


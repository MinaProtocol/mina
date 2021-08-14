#!/bin/bash

set -eou pipefail

function cleanup
{
  echo "Killing archive.exe"
  kill $(ps aux | egrep '/mina-bin/.*archive.exe' | grep -v grep | awk '{ print $2 }') || true
  echo "Killing mina.exe"
  kill $(ps aux | egrep '/mina-bin/.*mina.exe'    | grep -v grep | awk '{ print $2 }') || true
  echo "Killing rosetta.exe"
  kill $(ps aux | egrep '/mina-bin/rosetta'       | grep -v grep | awk '{ print $2 }') || true
  echo "Stopping postgres"
  pg_ctlcluster 11 main stop
  exit
}

trap cleanup TERM
trap cleanup INT

PG_CONN=postgres://$USER:$USER@localhost:5432/archiver

POSTGRES_VERSION=$(psql -V | cut -d " " -f 3 | sed 's/.[[:digit:]]*$//g')

# Start postgres
pg_ctlcluster ${POSTGRES_VERSION} main start

# wait for it to settle
sleep 3

export MINA_PRIVKEY_PASS=""
export MINA_LIBP2P_HELPER_PATH=/mina-bin/libp2p_helper

export MINA_CONFIG_FILE=${MINA_CONFIG_FILE:=/data/genesis_ledgers/devnet.json}
export PEER_LIST_URL=${PEER_LIST_URL:=https://storage.googleapis.com/seed-lists/devnet_seeds.txt}
export MINA_DAEMON_PORT=${MINA_DAEMON_PORT:=10101}
export MINA_ARCHIVE_PORT=${MINA_ARCHIVE_PORT:=3086}
export MINA_ROSETTA_PORT=${MINA_ROSETTA_PORT:=3087}
DEFAULT_FLAGS="-peer-list-url ${PEER_LIST_URL} -archive-address 0.0.0.0:${MINA_ARCHIVE_PORT} -insecure-rest-server -log-level debug -external-port ${MINA_DAEMON_PORT}"
export MINA_FLAGS=${MINA_FLAGS:=$DEFAULT_FLAGS}
PK=${MINA_PK:=ZsMSUuKL9zLAF7sMn951oakTFRCCDw9rDfJgqJ55VMtPXaPa5vPwntQRFJzsHyeh8R8}

echo "MINA Flags: $MINA_FLAGS -config-file ${MINA_CONFIG_FILE}"

# archive
/mina-bin/archive/archive.exe run \
  -postgres-uri $PG_CONN \
  -config-file ${MINA_CONFIG_FILE} \
  -server-port ${MINA_ARCHIVE_PORT} &

# wait for it to settle
sleep 3

# Daemon w/ config file
# Use MINA_CONFIG_FILE=/data/genesis_ledgers/mainnet.json to run on mainnet
/mina-bin/cli/src/mina.exe daemon \
    -config-file ${MINA_CONFIG_FILE} \
    ${MINA_FLAGS} $@ &

# wait for it to settle
sleep 3

# rosetta
/mina-bin/rosetta/rosetta.exe \
  -archive-uri $PG_CONN \
  -graphql-uri http://localhost:3085/graphql \
  -log-level debug \
  -port ${MINA_ROSETTA_PORT} &

# wait for a signal
sleep infinity

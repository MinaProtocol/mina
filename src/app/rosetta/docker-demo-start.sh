#!/bin/bash

set -eou pipefail

function cleanup
{
  CODE=${1:-0}
  echo "Killing archive.exe"
  kill $(ps aux | egrep '_build/default/src/app/.*archive.exe' | grep -v grep | awk '{ print $2 }') || true
  echo "Killing coda.exe"
  kill $(ps aux | egrep '_build/default/src/app/.*coda.exe'    | grep -v grep | awk '{ print $2 }') || true
  echo "Killing rosetta.exe"
  kill $(ps aux | egrep '_build/default/src/app/rosetta'       | grep -v grep | awk '{ print $2 }') || true
  exit $CODE
}

trap cleanup TERM
trap cleanup INT

PG_CONN=postgres://$USER:$USER@localhost:5432/archiver

# Start postgres
echo "========================= STARTING POSTGRESQL ==========================="
pg_ctlcluster 11 main start

# wait for it to settle
sleep 3

# archive
echo "========================= STARTING ARCHIVE PROCESS ==========================="
/coda-bin/archive/archive.exe run \
  -postgres-uri $PG_CONN \
  -server-port 3086 \
  -log-level fatal \
  -log-json &

# wait for it to settle
sleep 3

# Setup and run demo-node
PK=${PK:-B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g}
SNARK_PK=${SNARK_PK:-B62qiWSQiF5Q9CsAHgjMHoEEyR2kJnnCvN9fxRps2NXULU15EeXbzPf}
genesis_time=$(date -d '2019-01-30 20:00:00.000000Z' '+%s')
now_time=$(date +%s)
export CODA_TIME_OFFSET=$(( $now_time - $genesis_time ))
export CODA_PRIVKEY_PASS=""
export CODA_LIBP2P_HELPER_PATH=/coda-bin/libp2p_helper
CODA_CONFIG_DIR=/root/.coda-config

# CODA_CONFIG_DIR is exposed by the dockerfile and contains demo mode essentials
echo "========================= STARTING DAEMON ==========================="
/coda-bin/cli/src/coda.exe daemon \
  -archive-address 3086 \
  -background \
  -block-producer-key "$CODA_CONFIG_DIR/wallets/store/$PK" \
  -config-dir "$CODA_CONFIG_DIR" \
  -config-file "$CODA_CONFIG_DIR/daemon.json" \
  -genesis-ledger-dir "$CODA_CONFIG_DIR/demo-genesis" \
  -demo-mode \
  -disable-telemetry \
  -external-ip 127.0.0.1 \
  -external-port "${CODA_DAEMON_PORT:-10101}" \
  -insecure-rest-server \
  -log-level debug \
  -log-json \
  -run-snark-worker $SNARK_PK \
  -seed \
  $@

# Possibly useful flags:
#   Rosetta documentation specifies that /data/ will be a volume mount for various state.
#  -working-dir /data/ \
#   Demo mode probably doesnt need to be super strict about proving to integrate against rosetta.
#  -proof-level none \


# wait for it to settle
sleep 3

# rosetta
echo "========================= STARTING ROSETTA API on PORT 3087 ==========================="
/coda-bin/rosetta/rosetta.exe \
  -archive-uri $PG_CONN \
  -graphql-uri http://localhost:3085/graphql \
  -log-level debug \
  -port 3087 &

sleep infinity

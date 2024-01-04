#!/bin/bash

BLOCKS_BUCKET="${BLOCKS_BUCKET:=https://storage.googleapis.com/mina_network_block_data}"

set -u

MINA_NETWORK=${1}
# Postgres database connection string and related variables
POSTGRES_DBNAME=${2}
POSTGRES_USERNAME=${3}
PG_CONN=postgres://${POSTGRES_USERNAME}:${POSTGRES_USERNAME}@127.0.0.1:5432/${POSTGRES_DBNAME}

function jq_parent_json() {
   jq -rs 'map(select(.metadata.parent_hash != null and .metadata.parent_height != null)) | "\(.[0].metadata.parent_height)-\(.[0].metadata.parent_hash).json"'
}

function jq_parent_hash() {
   jq -rs 'map(select(.metadata.parent_hash != null and .metadata.parent_height != null)) | .[0].metadata.parent_hash'
}

function populate_db() {
   mina-archive-blocks --precomputed --archive-uri "$1" "$2" | jq -rs '"[BOOTSTRAP] Populated database with block: \(.[-1].message)"'
   rm "$2"
}

function download_block() {
    echo "Downloading $1 block"
    curl -sO "${BLOCKS_BUCKET}/${1}"
}

HASH='map(select(.metadata.parent_hash != null and .metadata.parent_height != null)) | .[0].metadata.parent_hash'
# Bootstrap finds every missing state hash in the database and imports them from the o1labs bucket of .json blocks
function bootstrap() {
  echo "[BOOTSTRAP] Top 10 blocks before bootstrapping the archiveDB:"
  psql "${PG_CONN}" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
  echo "[BOOTSTRAP] Restoring blocks individually from ${BLOCKS_BUCKET}..."

  until [[ "$PARENT" == "null" ]] ; do
    PARENT_FILE="${MINA_NETWORK}-$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq_parent_json)"
    download_block "${PARENT_FILE}"
    populate_db "$PG_CONN" "$PARENT_FILE"
    PARENT="$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq_parent_hash)"
  done

  echo "[BOOTSTRAP] Top 10 blocks in bootstrapped archiveDB:"
  psql "${PG_CONN}" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
  echo "[BOOTSTRAP] This rosetta node is synced with no missing blocks back to genesis!"

  echo "[BOOTSTRAP] Checking again in 60 minutes..."
  sleep 3000
}

# Wait until there is a block missing
PARENT=null
while true; do # Test once every 10 minutes forever, take an hour off when bootstrap completes
  PARENT="$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq_parent_hash)"
  echo "[BOOTSTRAP] $(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq -rs .[].message)"
  [[ "$PARENT" != "null" ]] && echo "[BOOSTRAP] Some blocks are missing, moving to recovery logic..." && bootstrap
  sleep 600 # Wait for the daemon to catchup and start downloading new blocks
done
echo "[BOOTSTRAP] This rosetta node is synced with no missing blocks back to genesis!"

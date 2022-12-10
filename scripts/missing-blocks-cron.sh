#!/bin/bash

BLOCKS_BUCKET="${BLOCKS_BUCKET:=https://storage.googleapis.com/mina_network_block_data}"

set -u

MINA_NETWORK=${1}

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
# Find every missing state hash in the database and imports them from the o1labs bucket of .json blocks
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
echo "[BOOTSTRAP] This archive node is synced with no missing blocks back to genesis!"
exit 0

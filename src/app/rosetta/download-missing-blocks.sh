#!/bin/bash

set -eou pipefail

BLOCKS_BUCKET="${BLOCKS_BUCKET:=https://storage.googleapis.com/mina_network_block_data}"

export MINA_NETWORK=${1}
# Postgres database connection string and related variables
POSTGRES_DBNAME=${2}
POSTGRES_USERNAME=${3}
PG_CONN=postgres://${POSTGRES_USERNAME}:${POSTGRES_USERNAME}@127.0.0.1:5432/${POSTGRES_DBNAME}

# Saved for future use with mina-replayer verification logic
export MINA_CONFIG_FILE=/genesis_ledgers/${MINA_NETWORK}.json
export MINA_CONFIG_DIR="${MINA_CONFIG_DIR:=/data/.mina-config}"

# Wait until there is a block missing
PARENT=null
for i in {1..6}; do # Test every 5 minutes for the first 30 minutes
  PARENT="$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq -rs .[-1].metadata.parent_hash)"
  echo "[BOOTSTRAP] $(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq -rs .[-1].message)"
  [[ "$PARENT" != "null" ]] && echo "[BOOSTRAP] Some blocks are missing, moving to reovery logic..." && break
  sleep 300 # Wait for the daemon to catchup and start downloading new blocks
done

echo "[BOOTSTRAP] Top 10 blocks before bootstrapping the archiveDB:"
psql "${PG_CONN}" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
echo "[BOOTSTRAP] Restoring blocks individually from ${BLOCKS_BUCKET}..."

# Continue until no more blocks are missing
until [[ "$PARENT" == "null" ]] ; do
  PARENT_FILE="$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq -rs '.[-1].metadata | "'${MINA_NETWORK}'-\(.parent_height)-\(.parent_hash).json"')"
  echo "Downloading $PARENT_FILE block"
  curl -sO "${BLOCKS_BUCKET}/${PARENT_FILE}"
  mina-archive-blocks --precomputed --archive-uri "$PG_CONN" "$PARENT_FILE" | jq -rs '"[BOOTSTRAP] Populated database with block: \(.[-1].message)"'
  rm "$PARENT_FILE"
  PARENT="$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq -rs .[-1].metadata.parent_hash)"
done

echo "[BOOTSTRAP] Top 10 blocks in bootstrapped archiveDB:"
psql "${PG_CONN}" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"

echo "[BOOTSTRAP] This rosetta node is synced with no missing blocks back to genesis!"

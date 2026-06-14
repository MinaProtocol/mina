#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 precomputed-log-file [output-folder]"
  exit 1
fi

PG_USER=${PG_USER:-postgres}
PG_PASSWD=${PG_PW:-""}
PG_DB=${PG_DB:-archive}
PG_HOST=${PG_HOST:-localhost}
PG_PORT=${PG_PORT:-5432}
PRECOMPUTED_LOG_FILE=$1
OUTPUT_FOLDER=${2:-precomputed_blocks}

cd "${OUTPUT_FOLDER}" || exit

while IFS= read -r line; do
	# Identify the block uniquely. ledger_hash is NOT unique: consecutive empty
	# blocks in a low-traffic network share a staged ledger hash, so a lookup by
	# ledger_hash alone returns many rows -> ambiguous filename (and an aborting
	# ambiguous redirect under `set -e`). The triple (height, parent_hash,
	# global_slot_since_genesis) pins down a single block.
	HEIGHT=$(echo "${line}" | jq -r '.data.protocol_state.body.consensus_state.blockchain_length')
	PARENT_HASH=$(echo "${line}" | jq -r '.data.protocol_state.previous_state_hash')
	GLOBAL_SLOT=$(echo "${line}" | jq -r '.data.protocol_state.body.consensus_state.global_slot_since_genesis')
	FILE_NAME=$(PGPASSWORD="${PG_PASSWD}" psql -h "${PG_HOST}" -p "${PG_PORT}" \
		-U "${PG_USER}" -d "${PG_DB}" -t \
		-c "SELECT 'mainnet-' || height || '-' || state_hash || '.json' FROM blocks WHERE height = ${HEIGHT} AND parent_hash = '${PARENT_HASH}' AND global_slot_since_genesis = ${GLOBAL_SLOT} ORDER BY id LIMIT 1" | xargs)
	if [[ -z "$FILE_NAME" ]] || [[ "$FILE_NAME" == "NULL" ]]; then
		echo "WARNING: No block found in db for height=${HEIGHT} parent=${PARENT_HASH} slot=${GLOBAL_SLOT}"
		continue
	fi
	echo  "${line}" > "${FILE_NAME}"
done < "${PRECOMPUTED_LOG_FILE}"



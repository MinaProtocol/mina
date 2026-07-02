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
	# Identify the block uniquely. ledger_hash is NOT unique (consecutive empty
	# blocks share a staged ledger hash) and neither is (height, parent_hash,
	# global_slot_since_genesis): two stakeholders can both win the same slot and
	# extend the same parent (a slot collision / short-range fork), producing two
	# distinct blocks with the same (height, parent, slot) that differ only in
	# last_vrf_output. Including last_vrf_output yields a key that is unique per
	# block, so every block (including both sides of a fork) gets its own file and
	# the canonical chain is never dropped. last_vrf_output is stored in the db
	# base64-encoded exactly as it appears in the precomputed-block JSON.
	HEIGHT=$(echo "${line}" | jq -r '.data.protocol_state.body.consensus_state.blockchain_length')
	PARENT_HASH=$(echo "${line}" | jq -r '.data.protocol_state.previous_state_hash')
	GLOBAL_SLOT=$(echo "${line}" | jq -r '.data.protocol_state.body.consensus_state.global_slot_since_genesis')
	VRF=$(echo "${line}" | jq -r '.data.protocol_state.body.consensus_state.last_vrf_output')
	FILE_NAME=$(PGPASSWORD="${PG_PASSWD}" psql -h "${PG_HOST}" -p "${PG_PORT}" \
		-U "${PG_USER}" -d "${PG_DB}" -t \
		-c "SELECT 'mainnet-' || height || '-' || state_hash || '.json' FROM blocks WHERE height = ${HEIGHT} AND parent_hash = '${PARENT_HASH}' AND global_slot_since_genesis = ${GLOBAL_SLOT} AND last_vrf_output = '${VRF}' ORDER BY id LIMIT 1" | xargs)
	if [[ -z "$FILE_NAME" ]] || [[ "$FILE_NAME" == "NULL" ]]; then
		echo "WARNING: No block found in db for height=${HEIGHT} parent=${PARENT_HASH} slot=${GLOBAL_SLOT} vrf=${VRF}"
		continue
	fi
	echo  "${line}" > "${FILE_NAME}"
done < "${PRECOMPUTED_LOG_FILE}"



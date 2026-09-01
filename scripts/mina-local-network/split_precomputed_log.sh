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
	# A staged-ledger hash is NOT unique (empty blocks share one), so matching on
	# it alone returns many rows -> a concatenated, too-long filename. A block is
	# uniquely identified by (height, parent_hash, ledger_hash, global_slot_since_genesis).
	# Restrict to canonical blocks so orphaned/forked log entries are skipped.
	HEIGHT=$(echo "${line}" | jq -r '.data.protocol_state.body.consensus_state.blockchain_length')
	PARENT_HASH=$(echo "${line}" | jq -r '.data.protocol_state.previous_state_hash')
	LEDGER_HASH=$(echo "${line}" | jq -r '.data.protocol_state.body.blockchain_state.staged_ledger_hash.non_snark.ledger_hash')
	GLOBAL_SLOT=$(echo "${line}" | jq -r '.data.protocol_state.body.consensus_state.global_slot_since_genesis')
	FILE_NAME=$(PGPASSWORD="${PG_PASSWD}" psql -h "${PG_HOST}" -p "${PG_PORT}" \
		-U "${PG_USER}" -d "${PG_DB}" -t -A \
		-c "SELECT 'mainnet-' || height || '-' || state_hash || '.json' FROM blocks \
		    WHERE height = ${HEIGHT} \
		      AND parent_hash = '${PARENT_HASH}' \
		      AND ledger_hash = '${LEDGER_HASH}' \
		      AND global_slot_since_genesis = ${GLOBAL_SLOT} \
		      AND chain_status = 'canonical'")
	if [[ -z "$FILE_NAME" ]] || [[ "$FILE_NAME" == "NULL" ]]; then
		echo "Skipping non-canonical/unknown block (height ${HEIGHT}, ledger ${LEDGER_HASH})"
		continue
	fi
	echo  "${line}" > "${FILE_NAME}"
done < "${PRECOMPUTED_LOG_FILE}"



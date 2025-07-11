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
PG_URI="postgresql://${PG_USER}:${PG_PASSWD}@${PG_HOST}:${PG_PORT}/${PG_DB}"
ARCHIVE_URI=${ARCHIVE_URI:-${PG_URI}}
PRECOMPUTED_LOG_FILE=$1
OUTPUT_FOLDER=${2:-precomputed_blocks}

cd "${OUTPUT_FOLDER}" || exit

while IFS= read -r line; do
	LEDGER_HASH=$(echo "${line}" | jq -r '.data.protocol_state.body.blockchain_state.staged_ledger_hash.non_snark.ledger_hash')
	FILE_NAME=$(PGPASSWORD="${PG_PASSWD}" psql -h "${PG_HOST}" -p "${PG_PORT}" \
		-U "${PG_USER}" -d "${PG_DB}" -t \
		-c "SELECT 'mainnet-' || height || '-' ||state_hash || '.json' FROM blocks WHERE ledger_hash = '$LEDGER_HASH'" | xargs)
	if [[ -z "$FILE_NAME" ]] || [[ "$FILE_NAME" == "NULL" ]]; then
		echo "WARNING: No block found in db for ledger hash: $LEDGER_HASH"
		continue
	fi
	echo  "${line}" > "${FILE_NAME}"
done < "${PRECOMPUTED_LOG_FILE}"



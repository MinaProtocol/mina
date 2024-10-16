#!/usr/bin/env bash

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 precomputed-log-file [output-folder]"
  exit 1
fi



ARCHIVE_URI=${ARCHIVE_URI:-postgres://postgres@localhost:5432/archive}
PRECOMPUTED_LOG_FILE=$1

while IFS= read -r line; do
	LEDGER_HASH=$(echo $line | jq -r '.protocol_state.body.blockchain_state.staged_ledger_hash.non_snark.ledger_hash')
	FILE_NAME=$(psql $ARCHIVE_URI -t -c "SELECT 'mainnet-' || height || '-' ||state_hash || '.json' FROM blocks WHERE ledger_hash = '$LEDGER_HASH'")
	echo  $line > $FILE_NAME 
done < $PRECOMPUTED_LOG_FILE



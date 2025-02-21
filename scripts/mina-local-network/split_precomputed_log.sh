#!/usr/bin/env bash

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 precomputed-log-file [output-folder]"
  exit 1
fi



ARCHIVE_URI=${ARCHIVE_URI:-postgres://postgres@localhost:5432/archive}
PRECOMPUTED_LOG_FILE=$1
OUTPUT_FOLDER=${2:precomputed_blocks}
cd $OUTPUT_FOLDER

while IFS= read -r line; do
	LEDGER_HASH=$(echo $line | jq -r '.data.protocol_state.body.blockchain_state.staged_ledger_hash.non_snark.ledger_hash')
  echo LEDGER_HASH $LEDGER_HASH
	FILE_NAME=$(psql -U postgres $ARCHIVE_URI -t -c "SELECT 'mainnet-' || height || '-' ||state_hash || '.json' FROM blocks WHERE ledger_hash = '$LEDGER_HASH'")
  if [[ -z "$FILE_NAME" ]]; then
    echo Warning FILE_NAME empty
  else
    echo creating $FILE_NAME
    echo  $line > $FILE_NAME
  fi
done < $PRECOMPUTED_LOG_FILE



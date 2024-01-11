#!/bin/bash

# fix-all-balances.sh -- patches bad combined fee transfer balances from genesis based on a swapped-balances.log file

# use the URI for your archive db
ARCHIVE_URI=${ARCHIVE_URI:-postgres://postgres@localhost:5432/archive}

# logs from the replayer
REPLAYER_LOG=${REPLAYER_LOG:-replayer.log}

# the log file generated with AWK script run on replayer log
LOG_FILE=${LOG_FILE:-swapped-balances.log}

# binary name/location for the mina replayer tool
REPLAYER=mina-replayer

# binary name/location for the mina swap bad balances tool
SWAPPER=mina-swap-bad-balances

read -p "State hash from canonical chain: " STATE_HASH

NETWORK=${NETWORK:-mainnet}
REPLAYER_INPUT=replayer_input.json

# Download the network configuration and rewrite it as replayer input
curl -s "https://raw.githubusercontent.com/MinaProtocol/mina/compatible/genesis_ledgers/${NETWORK}.json" | jq '{target_epoch_ledgers_state_hash:"'${STATE_HASH}'",genesis_ledger:{add_genesis_winner: true, accounts: .ledger.accounts}}' > $REPLAYER_INPUT

echo "---- Running replayer (takes over an hour, please be patient. Run tail -f ${REPLAYER_LOG} in another terminal to follow along.)"
$REPLAYER --archive-uri "${ARCHIVE_URI}" --input-file replayer_input.json --output-file /dev/null --continue-on-error > ${REPLAYER_LOG}

rm -f $REPLAYER_INPUT

echo "---- Finding swapped balances"

awk "$(curl -s https://raw.githubusercontent.com/MinaProtocol/mina/compatible/scripts/archive/find-swapped-balances.awk)" "${REPLAYER_LOG}" > "${LOG_FILE}"

BAD_COUNT=$(grep -- "-----" "${LOG_FILE}" | wc -l)

echo "Found $BAD_COUNT swapped balances"

# Read over each line of the LOG_FILE and call SWAPPER on each STATE_HASH, SEQ_NUMBER pair
while read -r
do
  if [[ ${REPLY} != "---------------" ]]; then

    EXTRACTED_HASH=$(printf "%s\n" "$REPLY" | jq -rM .metadata.state_hash)
    case "$EXTRACTED_HASH" in
      null)
        EXTRACTED_MESSAGE=$(printf "%s\n" "$REPLY" | jq -rM .message)
        SEQ_NUMBER="${EXTRACTED_MESSAGE##* }"
        echo "---- Swapping balances for state hash ${STATE_HASH} at sequence number ${SEQ_NUMBER} ----"
        "${SWAPPER}" --archive-uri "${ARCHIVE_URI}" --state-hash "${STATE_HASH}" --sequence-no "${SEQ_NUMBER}"
        ;;

      *)
        STATE_HASH=$EXTRACTED_HASH
    esac
  fi
done <"$LOG_FILE"

#!/bin/bash

# fix-all-balances.sh -- patches bad combined fee transfer balances from genesis based on a swapped-balances.log file

# use the URI for your archive db
ARCHIVE_URI=${ARCHIVE_URI:-postgres://postgres@localhost:5432/archive}

# use the log file generated with `awk -f scripts/archive/find-swapped-balances.awk replayer.log > swapped-balances.log`
LOG_FILE=${LOG_FILE:-swapped-balances.log}

# binary name/location for the mina swap bad balances tool
SWAPPER=mina-swap-bad-balances


# Read over each line of the LOG_FILE and call SWAPPER on each STATE_HASH, SEQ_NUMBER pair
while read -r
do

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

done <"$LOG_FILE"

#!/bin/bash 

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <connection-string> <target-block>"
  echo ""
  echo "Example: $0 postgres://postgres:postgres@localhost:5432/archive 3NLDtQqXRk7QybHS1b4quNoTKZDHUPeYRkRpKM641mxYjJEBwKCq"
  exit 1
fi

CONN_STR=$1
LAST_BLOCK_HASH=$2

GENESIS_HASH=$(psql "$CONN_STR" -t -c  \
    "select state_hash from blocks where id = 1;" | xargs)

PARENT_HASH=$(psql "$CONN_STR" -t -c  \
    "select parent_hash from blocks where state_hash = '$LAST_BLOCK_HASH';" | xargs)

if [ -z "$PARENT_HASH"  ]; then 
    echo "Error: Cannot find parent hash for $LAST_BLOCK_HASH. Please ensure block exists and database has no missing blocks"
    exit 1
fi

canon_chain=("$LAST_BLOCK_HASH")

echo "Calculating canonical chain..."
while [ -n "$PARENT_HASH" ] && [ "$PARENT_HASH" != "$GENESIS_HASH" ]
do
    PARENT_HASH=$(psql "$CONN_STR" -q -t -c  \
        "select parent_hash from blocks where state_hash = '$PARENT_HASH';" | xargs)

    canon_chain[${#canon_chain[@]}]="$PARENT_HASH"

done

echo "Updating non canonical blocks to orphaned..."
psql "$CONN_STR" -c "update blocks set chain_status = 'orphaned' where chain_status = 'pending';"

echo "Updating blocks statuses in canonical chain to canonical (${#canon_chain[@]})..."
for block in "${canon_chain[@]}"; do 
    psql "$CONN_STR" -q -c "update blocks set chain_status = 'canonical' where state_hash = '$block'"
done
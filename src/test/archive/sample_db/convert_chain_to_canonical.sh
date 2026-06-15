#/bin/bash

CONN_STR=$1
# Pick the tip as the highest block (the actual chain tip). Using MAX(global_slot)
# instead can select an off-tip fork block whose ancestry doesn't cover every
# height, producing an inconsistent canonical marking (a canonical child of an
# orphaned parent).
LAST_BLOCK_HASH=$(psql -U postgres $CONN_STR -t -c \
  'SELECT state_hash from blocks where height = (SELECT MAX(height) from blocks) ORDER BY id LIMIT 1;' \
  | head -n1 | xargs )

echo LAST_BLOCK_HASH: $LAST_BLOCK_HASH

GENESIS_HASH=$(psql $CONN_STR -t -c  \
    "select state_hash from blocks where id = 1;" | xargs)

canon_chain=($LAST_BLOCK_HASH)

PARENT_HASH=$(psql $CONN_STR -t -c  \
    "select parent_hash from blocks where state_hash = '$LAST_BLOCK_HASH';" | xargs)
HEIGHT=$(psql $CONN_STR -t -c  \
    "select height from blocks where state_hash = '$LAST_BLOCK_HASH';" | xargs)


while [ -n "$PARENT_HASH" ] && [ "$PARENT_HASH" != "$GENESIS_HASH" ]
do
    # Record the current ancestor BEFORE advancing. The previous version advanced
    # first and then recorded, which skipped the tip's direct parent and left a
    # one-block hole in the canonical chain.
    canon_chain[${#canon_chain[@]}]="$PARENT_HASH"

    PARENT_HASH=$(psql $CONN_STR -t -c  \
        "select parent_hash from blocks where state_hash = '$PARENT_HASH';" | xargs)
done

# Include the genesis block on the canonical chain.
canon_chain[${#canon_chain[@]}]="$GENESIS_HASH"

psql $CONN_STR -c "update blocks set chain_status = 'orphaned' where height <= $HEIGHT;"

for block in ${canon_chain[@]}; do
    psql $CONN_STR -c "update blocks set chain_status = 'canonical' where state_hash = '$block'"
done


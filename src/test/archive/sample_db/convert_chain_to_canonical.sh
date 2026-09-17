#/bin/bash

CONN_STR=$1
# Pick the tip as the highest block (longest chain), not the block with the
# greatest global_slot: with forks a stale orphan can hold the max slot, which
# would canonicalize the wrong (gapped) chain. A 2nd arg pins an explicit tip.
LAST_BLOCK_HASH=${2:-$(psql -U postgres $CONN_STR -t -c \
  'SELECT state_hash from blocks where height = (SELECT MAX(height) from blocks) ORDER BY state_hash;' \
  | head -n1 | xargs )}

echo LAST_BLOCK_HASH: $LAST_BLOCK_HASH

GENESIS_HASH=$(psql $CONN_STR -t -c  \
    "select state_hash from blocks where id = 1;" | xargs)

canon_chain=($LAST_BLOCK_HASH)

PARENT_HASH=$(psql $CONN_STR -t -c  \
    "select parent_hash from blocks where state_hash = '$LAST_BLOCK_HASH';" | xargs)
HEIGHT=$(psql $CONN_STR -t -c  \
    "select height from blocks where state_hash = '$LAST_BLOCK_HASH';" | xargs)


# Walk parent links to genesis. Append the current parent BEFORE advancing,
# otherwise the tip's immediate parent is skipped (off-by-one -> chain gap).
while [ -n "$PARENT_HASH" ] && [ "$PARENT_HASH" != "$GENESIS_HASH" ]
do
    canon_chain[${#canon_chain[@]}]="$PARENT_HASH"

    PARENT_HASH=$(psql $CONN_STR -t -c  \
        "select parent_hash from blocks where state_hash = '$PARENT_HASH';" | xargs)

done

psql $CONN_STR -c "update blocks set chain_status = 'orphaned' where height <= $HEIGHT;"

for block in ${canon_chain[@]}; do
    psql $CONN_STR -c "update blocks set chain_status = 'canonical' where state_hash = '$block'"
done


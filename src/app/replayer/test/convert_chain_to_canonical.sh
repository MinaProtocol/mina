#/bin/bash 

CONN_STR=$1
LAST_BLOCK_HASH=$2

GENESIS_HASH=$(psql $CONN_STR -t -c  \
    "select state_hash from blocks where id = 1;" | xargs)

canon_chain=($LAST_BLOCK_HASH)

PARENT_HASH=$(psql $CONN_STR -t -c  \
    "select parent_hash from blocks where state_hash = '$LAST_BLOCK_HASH';" | xargs)
HEIGHT=$(psql $CONN_STR -t -c  \
    "select height from blocks where state_hash = '$LAST_BLOCK_HASH';" | xargs)


while [ -n "$PARENT_HASH" ] && [ "$PARENT_HASH" != "$GENESIS_HASH" ]
do
    PARENT_HASH=$(psql $CONN_STR -t -c  \
        "select parent_hash from blocks where state_hash = '$PARENT_HASH';" | xargs)

    canon_chain[${#canon_chain[@]}]="$PARENT_HASH"

done

psql $CONN_STR -c "update blocks set chain_status = 'orphaned' and height < $HEIGHT;"

for block in ${canon_chain[@]}; do 
    psql $CONN_STR -c "update blocks set chain_status = 'canonical' where state_hash = '$block'"
done


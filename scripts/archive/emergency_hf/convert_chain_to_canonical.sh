#!/bin/bash 

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <connection-string> <target-block> <protocol-version>"
  echo ""
  echo "Example: $0 postgres://postgres:postgres@localhost:5432/archive 3NLDtQqXRk7QybHS1b4quNoTKZDHUPeYRkRpKM641mxYjJEBwKCq 1"
  exit 1
fi

PSQL=${PSQL:-psql}
CONN_STR=$1
LAST_BLOCK_HASH=$2
PROTOCOL_VERSION=$3

GENESIS_HASH=$($PSQL "$CONN_STR" -t -c  \
    "select state_hash from blocks where protocol_version_id = $PROTOCOL_VERSION and global_slot_since_hard_fork = 0 ;" | xargs)

GENESIS_ID=$($PSQL "$CONN_STR" -t -c  \
    "select id from blocks where protocol_version_id = $PROTOCOL_VERSION and global_slot_since_hard_fork = 0 ;" | xargs)

HEIGHT=$($PSQL "$CONN_STR" -t -c  \
    "select height from blocks where state_hash = '$LAST_BLOCK_HASH';" | xargs)

ID=$($PSQL "$CONN_STR" -t -c  \
    "select id from blocks where state_hash = '$LAST_BLOCK_HASH';" | xargs)


if [ -z "$ID"  ]; then 
    echo "Error: Cannot find id for $LAST_BLOCK_HASH. Please ensure block exists and database has no missing blocks"
    exit 1
else 
    echo Fork block id $ID
fi

if [ -z "$HEIGHT"  ]; then 
    echo "Error: Cannot find height for $LAST_BLOCK_HASH. Please ensure block exists and database has no missing blocks"
    exit 1
else 
    echo Fork block height $HEIGHT
fi


echo "Calculating canonical chain..."
canon_chain=$($PSQL $CONN_STR -U postgres -t -c  "WITH RECURSIVE chain AS ( 
                    SELECT id, parent_id, height,state_hash 
                    FROM blocks b WHERE b.id = $ID and b.protocol_version_id = $PROTOCOL_VERSION

                    UNION ALL 

                    SELECT b.id, b.parent_id, b.height,b.state_hash 
                    FROM blocks b 

                    INNER JOIN chain 

                    ON b.id = chain.parent_id AND (chain.id <> $GENESIS_ID OR b.id = $GENESIS_ID) WHERE b.protocol_version_id = $PROTOCOL_VERSION

                 ) 

                 SELECT id 
                 FROM chain ORDER BY height ASC"  | xargs)

canon_chain=(${canon_chain// / })

echo "Updating non canonical blocks to orphaned..."
$PSQL "$CONN_STR" -c "update blocks set chain_status = 'orphaned' where protocol_version_id = $PROTOCOL_VERSION;"

function join_by {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

echo "Updating blocks statuses in canonical chain to canonical (${#canon_chain[@]})..."
bs=500 
for ((i=0; i<${#canon_chain[@]}; i+=bs)); do
    echo " - $i of ${#canon_chain[@]}"
    IN_CLAUSE=$(join_by , ${canon_chain[@]:i:bs})
    $PSQL "$CONN_STR" -q -c "update blocks set chain_status = 'canonical' where id in (${IN_CLAUSE}) and protocol_version_id = $PROTOCOL_VERSION"
done
echo " - ${#canon_chain[@]} of ${#canon_chain[@]}"
#!/bin/bash

# add chain_status column to `blocks` table

# this script can be run multiple times, if new blocks
#  are added to the archive database

# from src/config/{mainnet,devnet}.mlh
K=290

PSQL="psql -t --no-align"
ARCHIVE=archive

echo "Creating the chain_status column, if it doesn't exist"
psql $ARCHIVE <<EOF
CREATE TYPE chain_status_type AS ENUM ('canonical', 'orphaned', 'pending');
ALTER TABLE blocks ADD COLUMN chain_status chain_status_type NOT NULL DEFAULT 'pending';
CREATE INDEX idx_chain_status ON blocks(chain_status)
EOF

echo "Marking genesis block as canonical"
$PSQL $ARCHIVE <<EOF
UPDATE blocks SET chain_status = 'canonical'
WHERE global_slot = 0
EOF

# get greatest canonical block height
GREATEST_CANONICAL_HEIGHT_QUERY="SELECT height FROM blocks WHERE chain_status='canonical' ORDER BY height DESC LIMIT 1"
GREATEST_CANONICAL_HEIGHT=$(/bin/echo $GREATEST_CANONICAL_HEIGHT_QUERY | $PSQL $ARCHIVE)

echo "Greatest canonical block height is" $GREATEST_CANONICAL_HEIGHT

# greatest greatest block height, use $1 or query db
GREATEST_HEIGHT_QUERY="SELECT max(height) FROM blocks"
GREATEST_HEIGHT=${1:-$(/bin/echo $GREATEST_HEIGHT_QUERY | $PSQL $ARCHIVE)}

echo "Greatest block height is" $GREATEST_HEIGHT

# find all blocks with the greatest height
TMPFILE_GREATEST=$(mktemp -t add-chain-status-greatest.XXXXX)
$PSQL $ARCHIVE <<EOF > $TMPFILE_GREATEST
SELECT state_hash FROM blocks
WHERE HEIGHT = $GREATEST_HEIGHT
EOF

TMPFILE_SUBCHAIN=$(mktemp -t add-chain-status-subchain.XXXXX)
EXPECTED_LENGTH=$(expr $GREATEST_HEIGHT - $GREATEST_CANONICAL_HEIGHT + 1)
FOUND_CHAIN=0

# the subchain is enumerated by ascending height, so blocks are marked
#  as canonical in order, starting from those already marked as canonical;
# there won't be gaps among the canonical blocks, and
#  if the script is interrupted, we can re-run the script to resume where
#  we left off
while read -r state_hash ; do
    echo "Looking for subchain from block with state hash" $state_hash "with length" $EXPECTED_LENGTH
    $PSQL --field-separator=" " $ARCHIVE <<EOF > $TMPFILE_SUBCHAIN
WITH RECURSIVE chain AS (

              SELECT id,state_hash,parent_id,height
              FROM blocks WHERE state_hash = '$state_hash'

              UNION ALL

              SELECT b.id,b.state_hash,b.parent_id,b.height
              FROM blocks b

              INNER JOIN chain

              ON b.id = chain.parent_id AND chain.height <> $GREATEST_CANONICAL_HEIGHT
           )

SELECT state_hash,height FROM chain ORDER BY height ASC
EOF

CHAIN_LENGTH=$(wc -l $TMPFILE_SUBCHAIN | awk '{print $1}')

if [ $CHAIN_LENGTH -eq $EXPECTED_LENGTH ]; then
    echo "Found a chain of length" $CHAIN_LENGTH
    FOUND_CHAIN=1
    break
fi
done < $TMPFILE_GREATEST

if [ $FOUND_CHAIN = 0 ]; then
    echo "*** Did not find a subchain back to a canonical block starting from height" $GREATEST_HEIGHT
    echo "*** Try passing a lower height as the first argument to this script"
    exit 1
fi

# mark chain statuses
while read -r state_hash height; do
    if [ $height -le $(expr $GREATEST_HEIGHT - $K) ]; then
	echo "Marking block with height" $height "and state hash" $state_hash "as canonical"
	$PSQL $ARCHIVE <<EOF
        UPDATE blocks SET chain_status = 'canonical'
        WHERE state_hash='$state_hash'
EOF
	echo "Marking other blocks with height" $height "as orphaned"
	$PSQL $ARCHIVE <<EOF
        UPDATE blocks SET chain_status = 'orphaned'
        WHERE height=$height AND state_hash<>'$state_hash'
EOF
    fi
done < $TMPFILE_SUBCHAIN

echo "Removing temporary files"
rm -f $TMPFILE_GREATEST
rm -f $TMPFILE_SUBCHAIN

#!/bin/bash

# add nonce column to `balances` table

PSQL="psql -t --no-align"
ARCHIVE=archive_balances_migrated

echo "Creating the nonce column, if it doesn't exist"
psql $ARCHIVE <<EOF
ALTER TABLE balances ADD COLUMN IF NOT EXISTS nonce bigint
EOF

FEE_PAYER_NONCE=$(mktemp -t fee-payer-nonce.XXXXX)

echo "Writing fee payer balance id and nonce to" $FEE_PAYER_NONCE

echo "Writing nonce data for fee payers"
$PSQL --field-separator=" " $ARCHIVE <<EOF > $FEE_PAYER_NONCE
SELECT fee_payer_balance,nonce FROM user_commands uc
INNER JOIN blocks_user_commands buc
ON uc.id = buc.user_command_id
EOF

echo "Wrote" $(cat $FEE_PAYER_NONCE | wc -l) "records for fee payer nonces"

while read -r balance_id nonce; do
    echo "Setting nonce to" $nonce "for balance id" $balance_id
    $PSQL -q $ARCHIVE <<EOF
    UPDATE balances SET nonce = $nonce + 1
    WHERE id = $balance_id
EOF
done < $FEE_PAYER_NONCE

BALANCES_NULL_NONCES=$(mktemp -t balances-null-nonces.XXXXX)

# write the balance records that are missing nonces

echo "Writing data for balances with NULL nonces"
$PSQL --field-separator=" " $ARCHIVE <<EOF > $BALANCES_NULL_NONCES
SELECT id, public_key_id, block_height, block_sequence_no
FROM balances
WHERE nonce IS NULL
EOF

echo "Wrote" $(cat $BALANCES_NULL_NONCES | wc -l) "records for balances with NULL nonces"

# get the nonces for those balance records

BALANCES_UPDATE_NONCES=$(mktemp -t balances-update-nonces.XXXXX)

echo "Writing data for updating NULL nonces"
while read -r balance_id public_key_id block_height block_sequence_no; do
    echo "Writing nonces for public key id" $public_key_id "at block height" $block_height "and sequence no" $block_sequence_no
    $PSQL --field-separator=" " $ARCHIVE <<EOF >> $BALANCES_UPDATE_NONCES
    SELECT $balance_id, nonce FROM balances
    WHERE public_key_id = $public_key_id
    AND block_height <= $block_height
    AND block_sequence_no <= $block_sequence_no
    AND nonce IS NOT NULL
    ORDER BY block_height, block_sequence_no, block_secondary_sequence_no DESC LIMIT 1
EOF
done < $BALANCES_NULL_NONCES

# do the updates

echo "Updating NULL nonces"
while read -r balance_id nonce; do
    echo "Updating balance with id" $balance_id "with nonce" $nonce
    $PSQL -q $ARCHIVE <<EOF
    UPDATE balances
    SET nonce = $nonce
    WHERE id = $id
EOF
done < $BALANCES_UPDATE_NONCES

echo "Adding zero nonces for remaining balance entries"
$PSQL -q $ARCHIVE <<EOF
UPDATE balances
SET nonce = 0
WHERE nonce IS NULL
EOF

echo "Make nonce column not-nullable"
$PSQL $ARCHIVE <<EOF
ALTER TABLE balances ALTER COLUMN nonce SET NOT NULL
EOF

rm -f $FEE_PAYER_NONCE
rm -f $BALANCES_NULL_NONCES
rm -f $BALANCES_UPDATE_NONCES

#!/bin/bash

# add account creation fee of 1 Mina to blocks_internal_commands for internal commands, where
# the balance is the command amount minus 1 Mina

ARCHIVE=archive
TMPFILE=$(mktemp -t internal-cmd-acct-fee.XXXXX)

psql $ARCHIVE <<EOF
ALTER TABLE blocks_internal_commands
ADD COLUMN receiver_account_creation_fee_paid bigint
EOF

# use `head` to strip header lines, trailing output
psql $ARCHIVE <<EOF | awk -F \| '(NR > 2){print $1 $2 $3 $4}' | head -n -2 > $TMPFILE
SELECT block_id, internal_command_id, sequence_no, secondary_sequence_no
FROM blocks_internal_commands AS bic
INNER JOIN internal_commands as ic
ON bic.internal_command_id = ic.id
INNER JOIN balances
ON bic.receiver_balance = balances.id
WHERE balances.balance = ic.fee - 1000000000
EOF

# if a coinbase has an associated fee transfer, add account creation fee if
# the balance is coinbase amount minus 1 Mina, minus the amount of the fee transfer
# an associated fee transfer is in the same block with the same sequence number as the coinbase
psql $ARCHIVE <<EOF | awk -F \| '(NR > 2){print $1 $2 $3 $4}' | head -n -2 >> $TMPFILE
SELECT bic_coinbase.block_id, bic_coinbase.internal_command_id, bic_coinbase.sequence_no, bic_coinbase.secondary_sequence_no
FROM blocks_internal_commands AS bic_coinbase
INNER JOIN internal_commands AS ic_coinbase
ON bic_coinbase.internal_command_id = ic_coinbase.id
INNER JOIN blocks_internal_commands AS bic_fee_transfer
ON bic_coinbase.block_id = bic_fee_transfer.block_id
AND bic_coinbase.sequence_no = bic_fee_transfer.sequence_no
INNER JOIN internal_commands AS ic_fee_transfer
ON ic_fee_transfer.id = bic_fee_transfer.internal_command_id
INNER JOIN balances
ON bic_coinbase.receiver_balance = balances.id
WHERE ic_coinbase.type = 'coinbase'
AND ic_fee_transfer.type = 'fee_transfer_via_coinbase'
AND balances.balance = ic_coinbase.fee - 1000000000 - ic_fee_transfer.fee
EOF

while read -r block_id internal_command_id sequence_no secondary_sequence_no; do
    psql $ARCHIVE <<EOF
    UPDATE blocks_internal_commands SET receiver_account_creation_fee_paid = 1000000000
    WHERE block_id=$block_id
    AND internal_command_id=$internal_command_id
    AND sequence_no=$sequence_no
    AND secondary_sequence_no=$secondary_sequence_no
EOF
done < $TMPFILE

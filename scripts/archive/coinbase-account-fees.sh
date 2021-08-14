#!/bin/bash

# add account creation fee to blocks_internal_commands for coinbases, where the balance is the coinbase amount minus 1 Mina

ARCHIVE=archive
TMPFILE=$(mktemp -t coinbase-acct-fee.XXXXX)

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
WHERE ic.type='coinbase' AND ((ic.fee = 1440000000000 AND balances.balance = 1439000000000) OR (ic.fee = 720000000000 AND balances.balance = 719000000000))
EOF

while read -r block_id internal_command_id sequence_no secondary_sequence_no; do
    psql $ARCHIVE <<EOF
    UPDATE blocks_internal_commands SET receiver_account_creation_fee_paid = 1000000000
    WHERE block_id=$block_id AND internal_command_id=$internal_command_id AND sequence_no=$sequence_no AND secondary_sequence_no=$secondary_sequence_no
EOF
done < $TMPFILE

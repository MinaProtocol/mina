#!/bin/bash

# add nonce column to `balances` table

ARCHIVE=archive

echo "Creating the nonce column, if it doesn't exist"
psql $ARCHIVE <<EOF
ALTER TABLE balances ADD COLUMN IF NOT EXISTS nonce bigint
EOF

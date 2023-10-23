#!/bin/bash

if [ ! $# -eq 1 ] ; then
    echo "Usage" $0 archive-db
    exit 0
fi

ARCHIVE_DB=$1
HASHES_FILE=hashes_file.tmp
UPDATE_SCRIPT=hashes_update.sql

rm -f $HASHES_FILE
rm -f $UPDATE_SCRIPT

echo "select id,receipt_chain_hash from zkapp_account_precondition where receipt_chain_hash is not null;" | \
    psql --csv -t -q $ARCHIVE_DB > $HASHES_FILE

for line in `cat $HASHES_FILE`
  do  (
    ID=$(echo $line | awk -F , '{print $1}');
    FP=$(echo $line | awk -F , '{print $2}');
    B58=$(echo $FP | _build/default/src/app/receipt_chain_hash_to_b58/receipt_chain_hash_to_b58.exe);
    echo $ID "'"$B58"'" | awk '{print "UPDATE zkapp_account_precondition SET receipt_chain_hash=" $2 " WHERE id=" $1 ";"}' >> $UPDATE_SCRIPT)
done

echo "Done!"
echo "Now run:" "psql -d" $ARCHIVE_DB "<" $UPDATE_SCRIPT

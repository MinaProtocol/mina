#!/bin/bash

if [ $# -lt 1 ] || [ $# -gt 3 ]; then
    echo "Usage" $0 archive-db [hashes_file] [update_script]
    echo "'hashes_file' and 'update_script' are created when running this script"
    exit 0
fi

ARCHIVE_DB=$1
HASHES_FILE=${2:-hashes_file.tmp}
UPDATE_SCRIPT=${3:-hashes_update.sql}

echo "Migrating receipt chain hashes in account preconditions in archive db '"$ARCHIVE_DB"'"
echo "Using temporary file '"$HASHES_FILE"' and creating SQL script '"$UPDATE_SCRIPT"'"

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

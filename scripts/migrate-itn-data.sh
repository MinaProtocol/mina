#!/bin/bash

if [ $# -lt 1 ] || [ $# -gt 3 ]; then
    echo "Usage" $0 archive-db [data_file] [update_script]
    echo "'data_file' and 'update_script' are created when running this script"
    exit 0
fi

ARCHIVE_DB=$1
DATA_FILE=${2:-data_file.tmp}
UPDATE_SCRIPT=${3:-data_update.sql}

echo "Migrating receipt chain hashes in account preconditions in archive db '"$ARCHIVE_DB"'"

rm -f $DATA_FILE
rm -f $UPDATE_SCRIPT

echo "Creating temporary file with receipt chain hashes" "'"$DATA_FILE"'"
echo "select id,receipt_chain_hash from zkapp_account_precondition where receipt_chain_hash is not null;" | \
    psql --csv -t -q $ARCHIVE_DB > $DATA_FILE

echo "Creating SQL script" "'"$UPDATE_SCRIPT"'"
for line in `cat $DATA_FILE`
  do  (
    ID=$(echo $line | awk -F , '{print $1}');
    FP=$(echo $line | awk -F , '{print $2}');
    B58=$(echo $FP | _build/default/src/app/receipt_chain_hash_to_b58/receipt_chain_hash_to_b58.exe);
    echo -n .
    echo $ID "'"$B58"'" | awk '{print "UPDATE zkapp_account_precondition SET receipt_chain_hash=" $2 " WHERE id=" $1 ";"}' >> $UPDATE_SCRIPT)
done

echo
echo "Receipt chain hash pass done!"

rm -f $DATA_FILE

echo "Creating temporary file with last_vrf_ouput" "'"$DATA_FILE"'"
echo "select id,last_vrf_output from blocks;" | \
    psql --csv -t -q $ARCHIVE_DB > $DATA_FILE

echo "Adding to SQL script" "'"$UPDATE_SCRIPT"'"
for line in `cat $DATA_FILE`
  do  (
    ID=$(echo $line | awk -F , '{print $1}');
    FP=$(echo $line | awk -F , '{print $2}');
    B64=$(echo $FP | _build/default/src/app/last_vrf_output_to_b64/last_vrf_output_to_b64.exe);
    echo -n .
    echo $ID "'"$B64"'" | awk '{print "UPDATE blocks SET last_vrf_output=" $2 " WHERE id=" $1 ";"}' >> $UPDATE_SCRIPT)
done

echo
echo "Last VRF output pass done!"

echo "Now run:" "psql -d" $ARCHIVE_DB "<" $UPDATE_SCRIPT

#!/bin/bash

set -e

if [ $# -ne 1 ]; then
    echo "Usage $0 archive-db"
    exit 0
fi

ARCHIVE_DB=$1
BODY_DATA_BCK=zkapp_update_body_data_table.bck
PRECONDITION_DATA_BCK=zkapp_precondition_table.bck
PRECONDITION_DATA_TMP=zkapp_precondition_table.tmp
PRECONDITION_UPDATE_SCRIPT=zkapp_precondition_script.sql
BODY_UPDATE_SCRIPT=zkapp_update_body_script.sql

echo "This Shell script will produce two SQL scripts that will remove duplicated zkApp account preconditions rows in the archive DB" "$ARCHIVE_DB"

rm -f $BODY_DATA_BCK
rm -f $PRECONDITION_DATA_BCK
rm -f $PRECONDITION_DATA_TMP
rm -f $PRECONDITION_UPDATE_SCRIPT
rm -f $BODY_UPDATE_SCRIPT

ALL_TABLES="balance_id,receipt_chain_hash,delegate_id,state_id,action_state_id,proved_state, is_new, nonce_id"

echo "Creating backup of zkapp_account_preconditions table " "$PRECONDITION_DATA_BCK" 

echo "SELECT * FROM zkapp_account_precondition" | \
    psql -U postgres --csv -q -t "$ARCHIVE_DB" > $PRECONDITION_DATA_BCK

echo "Creating backup of zkapp_update_body table " "$BODY_DATA_BCK"

echo "SELECT * FROM zkapp_account_update_body" | \
    psql -U postgres --csv -q -t "$ARCHIVE_DB" > $BODY_DATA_BCK


echo "Creating temporary file of zkapp_account_preconditions table with duplicated rows" "$PRECONDITION_DATA_TMP"

echo "SELECT  MIN(id) as id, $ALL_TABLES, MAX(id) as duplicated_id  \
		FROM zkapp_account_precondition \
		GROUP BY $ALL_TABLES \
		HAVING COUNT(*) > 1" | \
    psql -U postgres --csv -q -t "$ARCHIVE_DB" > $PRECONDITION_DATA_TMP


if [[ $(wc -l < $PRECONDITION_DATA_TMP) -gt 0 ]]; then
    
    echo "Creating SQL scripts for removing duplications" "$PRECONDITION_UPDATE_SCRIPT" "and updating references" "$BODY_UPDATE_SCRIPT"

    cat $PRECONDITION_DATA_TMP | while IFS= read -r line 
    do  
        ID_TO_REPLACE=$(echo "$line" | awk -F , '{print $1}');
        ID_TO_REMOVE=$(echo "$line" | awk -F , '{print $10}');
        echo -n .
        echo "$ID_TO_REPLACE $ID_TO_REMOVE" | awk '{print "UPDATE zkapp_account_update_body SET zkapp_account_precondition_id = " $1 " WHERE zkapp_account_precondition_id =" $2 ";"}' >> $BODY_UPDATE_SCRIPT
        echo "$ID_TO_REMOVE" | awk '{print "DELETE FROM zkapp_account_precondition WHERE id=" $1 ";"}' >> $PRECONDITION_UPDATE_SCRIPT
    done
    
    echo
    echo "SQL scripts are ready: $PRECONDITION_UPDATE_SCRIPT, $BODY_UPDATE_SCRIPT !"
else
    echo
    echo "No duplicated rows found. Database state is correct !"
fi

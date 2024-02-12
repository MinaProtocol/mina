#!/bin/bash

echo "Starting migration cron job";

set -x

KEY_FILE_ARG="Credentials:gs_service_key_file=/gcloud/keyfile.json"

# DUMPS
DUMPS_BUCKET="${DUMPS_BUCKET:-}"

DUMPS_PREFIX_FROM="${DUMPS_PREFIX_FROM:-}"
SCHEMA_NAME_FROM="${SCHEMA_NAME_FROM:-}"

DUMPS_PREFIX_TO="${DUMPS_PREFIX_TO:-}"
SCHEMA_NAME_TO="${SCHEMA_NAME_TO:-}"

# GENESIS_LEDGER
GENESIS_LEDGER_URI="${GENESIS_LEDGER_URI:-https://github.com/MinaProtocol/mina/raw/testing/hard-fork-internal/genesis_ledgers/devnet.json}"

#ARCHIVE
CREATE_SCRIPT_URI="${CREATE_SCRIPT_URI:-https://raw.githubusercontent.com/MinaProtocol/mina/berkeley/src/app/archive}"

# PRECOMPUTED LOGS
PRECOMP_BLOCKS_BUCKET="${PRECOMP_BLOCKS_BUCKET:-}"
NETWORK_NAME="${NETWORK_NAME:-}"

# MIGRATION LOG
MIGRATION_LOG="${DUMPS_PREFIX_TO:-}"

DATE=$(date '+%Y-%m-%d_%H%M')
INITIAL_RUN=${INITIAL_RUN:-false}

END_GLOBAL_HASH="${END_GLOBAL_HASH:-}"

PG_CONN_STRING=postgres://postgres:postgres@localhost:5432


# Install perequisitives such as gsutil wget etc.
install_prereqs () {
	echo "Installing prequisitives..."

	echo "Updating packages";
	apt update;
	echo "Installing libjemalloc2";
	apt-get -y install libjemalloc2;

	echo "Installing Utils (curl, wget etc.)";
	apt-get -y install apt-transport-https ca-certificates gnupg curl wget;

	echo "Installing gsutil";
	echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list;
	curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - ;
	apt-get update && apt-get install -y google-cloud-cli ;

}


# Imports dumps based on prefix and schema
# Downloads archive from '$DUMPS_BUCKET' bucket and untars it and finally imports into local database
import_dump () {

	PREFIX=$1
	SCHEMA=$2

	echo "Importing ${SCHEMA} archive..."

	echo "Fetching newest dump from ${DUMPS_BUCKET} starting with ${PREFIX}"

	ARCHIVE_DUMP_URI=$(gsutil -o "$KEY_FILE_ARG" ls gs://${DUMPS_BUCKET}/${PREFIX}-*.sql.tar.gz | sort -r | head -n 1);
	ARCHIVE_DUMP=$(basename $ARCHIVE_DUMP_URI);
	ARCHIVE_SQL=$(basename $ARCHIVE_DUMP_URI .tar.gz);

	echo "Found lastest dump: " $ARCHIVE_DUMP_URI " . Downloading ...";
	gsutil -o "$KEY_FILE_ARG" cp $ARCHIVE_DUMP_URI . ;

	echo " Unpacking archive dump";
	tar -xzvf $ARCHIVE_DUMP;
	mv $ARCHIVE_SQL ~postgres/;
	echo "Deleting archive dump";
	rm -f $ARCHIVE_DUMP;
	
	echo "Creating schema and importing archive dump";
	su postgres -c "cd ~ && echo CREATE DATABASE $SCHEMA | psql";
	su postgres -c "cd ~ && psql -d $SCHEMA < $ARCHIVE_SQL";

	echo "Deleting archive SQL file";
	su postgres -c "cd ~ && rm -f $ARCHIVE_SQL";
	rm -f $ARCHIVE_SQL

}

# Creates target empty schema .
# Should be used on initial migration steps (when there is no existing partially migrated schema)
import_dump_frist_time () {
	SCHEMA=$1

	echo "Creating ${SCHEMA} archive..."

	echo "Fetching newest schema from "

	wget "${CREATE_SCRIPT_URI}"/create_schema.sql
	wget "${CREATE_SCRIPT_URI}"/zkapp_tables.sql
	
	ARCHIVE_SQL=create_schema.sql
	mv $ARCHIVE_SQL ~postgres/;
	mv zkapp_tables.sql ~postgres/;
	echo "Creating schema and importing archive dump";
	su postgres -c "cd ~ && echo CREATE DATABASE $SCHEMA | psql";
	su postgres -c "cd ~ && psql -d $SCHEMA < $ARCHIVE_SQL";

	echo "Deleting archive SQL file";
	su postgres -c "cd ~ && rm -f $ARCHIVE_SQL";
	rm -f $ARCHIVE_SQL

}

run_first_phase_of_migration() {


	echo "Starting migration Phase 1";

	echo "Downloading genesis_ledger";
	wget $GENESIS_LEDGER_URI -O genesis_ledger.json
	
	echo "Running berkeley migration app";
	
	if [ -z "${END_GLOBAL_HASH}" ]; then
		mina-berkeley-migration --mainnet-archive-uri ${PG_CONN_STRING}/"${SCHEMA_NAME_FROM}" --migrated-archive-uri ${PG_CONN_STRING}/"${SCHEMA_NAME_TO}" --batch-size 500 --config-file genesis_ledger.json --blocks-bucket "$PRECOMP_BLOCKS_BUCKET" --network "$NETWORK_NAME"  &> "${MIGRATION_LOG}".log
	else
		mina-berkeley-migration --mainnet-archive-uri ${PG_CONN_STRING}/"${SCHEMA_NAME_FROM}" --migrated-archive-uri ${PG_CONN_STRING}/"${SCHEMA_NAME_TO}" --batch-size 500 --config-file genesis_ledger.json --blocks-bucket "$PRECOMP_BLOCKS_BUCKET" --network "$NETWORK_NAME" --fork-state-hash $END_GLOBAL_HASH &> "${MIGRATION_LOG}".log
	fi
	
	echo "Done running berkeley migration app";

}

service postgresql start;
su postgres -c "cd ~ && echo ALTER USER postgres WITH PASSWORD \'postgres\' | psql";
	

install_prereqs

import_dump "${DUMPS_PREFIX_FROM}-archive-dump" $SCHEMA_NAME_FROM

if [[ "$INITIAL_RUN" == "true" ]]
then 
	import_dump_frist_time $SCHEMA_NAME_TO
else 
	import_dump "${DUMPS_PREFIX_TO}-archive-dump" $SCHEMA_NAME_TO
fi

run_first_phase_of_migration

grep Error ${MIGRATION_LOG}.log;

HAVE_ERRORS=$?;
if [ $HAVE_ERRORS -eq 0 ]; then 
  ERROR_LOG=${MIGRATION_LOG}_errors_${DATE}.log;
  echo "The berkeley_migration found errors, uploading log" $ERROR_LOG;
  mv ${MIGRATION_LOG}.log $ERROR_LOG;
  gsutil -o "$KEY_FILE_ARG" cp $ERROR_LOG gs://$DUMPS_BUCKET/$ERROR_LOG;  
else
  echo "No errors found! uploading migrated schema to ${DUMPS_BUCKET} bucket";
  UPLOAD_SCRIPT_NAME=${DUMPS_PREFIX_TO}-archive-dump-${DATE}_0000.sql
  su postgres -c "cd ~ && pg_dump $SCHEMA_NAME_TO > $UPLOAD_SCRIPT_NAME";
  UPLOAD_ARCHIVE_NAME=$UPLOAD_SCRIPT_NAME.tar.gz
  mv ~postgres/$UPLOAD_SCRIPT_NAME .
  tar -czvf $UPLOAD_ARCHIVE_NAME $UPLOAD_SCRIPT_NAME;
  gsutil -o "$KEY_FILE_ARG" cp $UPLOAD_ARCHIVE_NAME gs://$DUMPS_BUCKET;
fi
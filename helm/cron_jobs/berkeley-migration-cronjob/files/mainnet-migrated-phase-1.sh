#!/bin/bash

echo "Starting berkeley migration cron job";

KEY_FILE_ARG='-o Credentials:gs_service_key_file=/gcloud/keyfile.json'
DUMPS_BUCKET=mina-archive-dumps
DATE=$(date '+%Y-%m-%d')

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
	echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list;
	curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - ;
	apt-get update && apt-get install -y google-cloud-cli ;

}


# Imports dumps based on prefix and schema
# Downloads archive from 'mina-archive-dumps' bucket and untars it and finally imports into local database
import_dump () {

	PREFIX=$1
	SCHEMA=$2

	echo "Importing ${SCHEMA} archive..."


	echo "Fetching newest dump from ${DUMPS_BUCKET} starting with ${PREFIX}"

	ARCHIVE_DUMP_URI=$(gsutil $KEY_FILE_ARG ls gs://${DUMPS_BUCKET}/${PREFIX}-*.sql.tar.gz | sort -r | head -n 1);
	ARCHIVE_DUMP=$(basename $ARCHIVE_DUMP_URI);
	ARCHIVE_SQL=$(basename $ARCHIVE_DUMP_URI .tar.gz);

	echo "Found lastest dump: " $ARCHIVE_DUMP_URI " . Downloading ...";
	gsutil $KEY_FILE_ARG cp $ARCHIVE_DUMP_URI . ;

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

run_first_phase_of_migration() {


	echo "Starting migration Phase 1";

	echo "Downloading genesis_ledger/mainnet.json from newest rampup ";
	wget https://raw.githubusercontent.com/MinaProtocol/mina/rampup/genesis_ledgers/mainnet.json
	
	echo "Running berkeley migration app";
	mina-berkeley-migration --mainnet-archive-uri postgres://postgres:foobar@localhost/archive_balances_migrated --migrated-archive-uri postgres://postgres:foobar@localhost/mainnet_archive_migrated --batch-size 100 --config-file mainnet.json --mainnet-blocks-bucket "mina_network_block_data" &> mainnet_berkeley_migration.log
	echo "Done running berkeley migration app";

}

service postgresql start;
su postgres -c "cd ~ && echo ALTER USER postgres WITH PASSWORD \'foobar\' | psql";
	

install_prereqs

import_dump "mainnet-archive-dump" "archive_balances_migrated"

import_dump "mainnet-migrated-archive-dump" "mainnet_archive_migrated"

run_first_phase_of_migration

grep Error mainnet_berkeley_migration.log;

HAVE_ERRORS=$?;
if [ $HAVE_ERRORS -eq 0 ];
  then berkeley_migration_ERRORS=mainnet_berkeley_migration_errors_${DATE};
  echo "The berkeley_migration found errors, uploading log" $berkeley_migration_ERRORS;
  mv mainnet_berkeley_migration.log $berkeley_migration_ERRORS;
  gsutil $KEY_FILE_ARG cp $berkeley_migration_ERRORS gs://mina-archive-dumps/$berkeley_migration_ERRORS;  
else
  echo "No errors found! uploading migrated schema to ${DUMPS_BUCKET} bucket";
  UPLOAD_SCRIPT_NAME=mainnet-migrated-archive-dump-${DATE}_0000.sql
  su postgres -c "cd ~ && pg_dump mainnet_archive_migrated > $UPLOAD_SCRIPT_NAME";
  UPLOAD_ARCHIVE_NAME=$UPLOAD_SCRIPT_NAME.tar.gz
  mv ~postgres/$UPLOAD_SCRIPT_NAME .
  tar -czvf $UPLOAD_ARCHIVE_NAME $UPLOAD_SCRIPT_NAME;
  gsutil $KEY_FILE_ARG cp $UPLOAD_ARCHIVE_NAME gs://mina-archive-dumps;
fi
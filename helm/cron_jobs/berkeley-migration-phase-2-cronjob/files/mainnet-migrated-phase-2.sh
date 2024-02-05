#!/bin/bash

echo "Starting berkeley migration cron job";

KEY_FILE_ARG='-o Credentials:gs_service_key_file=/gcloud/keyfile.json'
DUMPS_BUCKET=mina-archive-dumps
DUMPS_PREFIX=hf_network
SCHEMA_NAME=mainnet_archive_migrated

CHECKPOINT_BUCKET=archive-migration-checkpoints
CHECKPOINT_PREFIX=berkeley-migration

# MIGRATION LOG
MIGRATION_LOG=mainnet_berkeley_migration

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

	ARCHIVE_DUMP_URI=$(gsutil "$KEY_FILE_ARG" ls gs://${DUMPS_BUCKET}/"${PREFIX}"-*.sql.tar.gz | sort -r | head -n 1);
	ARCHIVE_DUMP=$(basename "$ARCHIVE_DUMP_URI");
	ARCHIVE_SQL=$(basename "$ARCHIVE_DUMP_URI" .tar.gz);

	echo "Found lastest dump: " "$ARCHIVE_DUMP_URI" " . Downloading ...";
	gsutil "$KEY_FILE_ARG" cp "$ARCHIVE_DUMP_URI" . ;

	echo " Unpacking archive dump";
	tar -xzvf "$ARCHIVE_DUMP";
	mv "$ARCHIVE_SQL" ~postgres/;
	echo "Deleting archive dump";
	rm -f "$ARCHIVE_DUMP";
	
	echo "Creating schema and importing archive dump";
	su postgres -c "cd ~ && echo CREATE DATABASE $SCHEMA | psql";
	su postgres -c "cd ~ && psql -d $SCHEMA < $ARCHIVE_SQL";

	echo "Deleting archive SQL file";
	su postgres -c "cd ~ && rm -f $ARCHIVE_SQL";
	rm -f "$ARCHIVE_SQL"

}

run_second_phase_of_migration() {

	echo "Starting migration Phase 2";

	echo "Downloading newest checkpoint";
    MOST_RECENT_CHECKPOINT_URI=$(gsutil "$GSUTIL_ARGS" ls gs://$CHECKPOINT_BUCKET/$CHECKPOINT_PREFIX-replayer-checkpoint-*.json | sort -r | head -n 1);
    MOST_RECENT_CHECKPOINT=$(basename "$MOST_RECENT_CHECKPOINT_URI");
    
	echo "Running replayer in migration mode";
	mina-replayer --migration-mode --archive-uri postgres://postgres:postgres@localhost:5432/mainnet_migrated_archive --input-file "$MOST_RECENT_CHECKPOINT" --checkpoint-interval 100 --checkpoint-file-prefix $CHECKPOINT_PREFIX &> "${CHECKPOINT_PREFIX}_migration".log
	echo "Done running replayer in migration mode";

}

service postgresql start;
su postgres -c "cd ~ && echo ALTER USER postgres WITH PASSWORD \'foobar\' | psql";

install_prereqs

import_dump "${DUMPS_PREFIX}-archive-dump" "$SCHEMA_NAME"

run_second_phase_of_migration

grep Error ${CHECKPOINT_PREFIX}_migration.log;

HAVE_ERRORS=$?;
if [ $HAVE_ERRORS -eq 0 ];
  then berkeley_migration_ERRORS=${MIGRATION_LOG}_errors_${DATE};
  echo "The berkeley_migration found errors, uploading log" "$berkeley_migration_ERRORS";
  mv ${MIGRATION_LOG}.log "$berkeley_migration_ERRORS";
  gsutil "$KEY_FILE_ARG" cp "$berkeley_migration_ERRORS" gs://${DUMPS_BUCKET}/${CHECKPOINT_PREFIX}_migration_error.log;  
else
  echo "No errors found! uploading newest local checkpoint to ${CHECKPOINT_BUCKET} bucket";
  rm -f "$MOST_RECENT_CHECKPOINT";
  DISK_CHECKPOINT=$(ls -t ${CHECKPOINT_PREFIX}-checkpoint*.json | head -n 1);
  DATE=$(date +%F);
  TODAY_CHECKPOINT=$CHECKPOINT_PREFIX-checkpoint-$DATE.json;
  mv "$DISK_CHECKPOINT" "$TODAY_CHECKPOINT";
  echo "Uploading checkpoint file" "$TODAY_CHECKPOINT";
  gsutil "$KEY_FILE_ARG" cp "$UPLOAD_ARCHIVE_NAME" gs://$CHECKPOINT_BUCKET;
fi
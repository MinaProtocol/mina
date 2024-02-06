#!/bin/bash

echo "Starting berkeley migration cron job";

KEY_FILE_ARG="Credentials:gs_service_key_file=/gcloud/keyfile.json"

DUMPS_BUCKET="${DUMPS_BUCKET:-}"
DUMPS_PREFIX_FROM="${DUMPS_PREFIX_FROM:-}"
DUMPS_PREFIX_TO="${DUMPS_PREFIX_TO:-}"

SCHEMA_NAME="${SCHEMA_NAME:-}"

CHECKPOINT_BUCKET="${CHECKPOINT_BUCKET:-}"
CHECKPOINT_PREFIX="${CHECKPOINT_PREFIX:-}"

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
	echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list;
	curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - ;
	apt-get update && apt-get install -y google-cloud-cli ;

}


# Imports dumps based on prefix and schema
# Downloads archive from 'mina-archive-dumps' bucket and untars it and finally imports into local database
import_dump () {

	PREFIX=$1
	SCHEMA=$2

	echo "Importing ${SCHEMA} archive..."


	echo "Fetching newest dump from ${DUMPS_BUCKET} starting with ${PREFIX}"

	ARCHIVE_DUMP_URI=$(gsutil -o "$KEY_FILE_ARG" ls gs://${DUMPS_BUCKET}/"${PREFIX}"-*.sql.tar.gz | sort -r | head -n 1);
	ARCHIVE_DUMP=$(basename "$ARCHIVE_DUMP_URI");
	ARCHIVE_SQL=$(basename "$ARCHIVE_DUMP_URI" .tar.gz);

	echo "Found lastest dump: " "$ARCHIVE_DUMP_URI" " . Downloading ...";
	gsutil -o "$KEY_FILE_ARG" cp "$ARCHIVE_DUMP_URI" . ;

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


run_second_phase_of_migration_first_time() {

	echo "Starting migration Phase 2";

	echo "Downloading genesis_ledger";
	wget https://github.com/MinaProtocol/mina/raw/testing/hard-fork-internal/genesis_ledgers/devnet.json -O ledger.json
	
	cat ledger.json | jq '.ledger.accounts' > accounts.json
	echo '{ "genesis_ledger": { "accounts": '$(cat accounts.json)' } }' | jq > initial_config.json
	
	echo "Running replayer in migration mode";
	mina-replayer --migration-mode --archive-uri postgres://postgres:foobar@localhost:5432/${SCHEMA_NAME} --input-file initial_config.json --checkpoint-interval 100 --checkpoint-file-prefix $CHECKPOINT_PREFIX &> "${CHECKPOINT_PREFIX}".log
	echo "Done running replayer in migration mode";

}

run_second_phase_of_migration() {

	echo "Starting migration Phase 2";

	echo "Downloading newest checkpoint";
    MOST_RECENT_CHECKPOINT_URI=$(gsutil -o "$KEY_FILE_ARG" ls gs://$CHECKPOINT_BUCKET/$CHECKPOINT_PREFIX-checkpoint-*.json | sort -r | head -n 1);
    MOST_RECENT_CHECKPOINT=$(basename "$MOST_RECENT_CHECKPOINT_URI");
    gsutil -o "$KEY_FILE_ARG" cp $MOST_RECENT_CHECKPOINT_URI . ;
             
	echo "Running replayer in migration mode";
	mina-replayer --migration-mode --archive-uri postgres://postgres:foobar@localhost:5432/${SCHEMA_NAME} --input-file "$MOST_RECENT_CHECKPOINT" --checkpoint-interval 100 --checkpoint-file-prefix $CHECKPOINT_PREFIX &> "${CHECKPOINT_PREFIX}".log
	echo "Done running replayer in migration mode";

}

service postgresql start;
su postgres -c "cd ~ && echo ALTER USER postgres WITH PASSWORD \'foobar\' | psql";

install_prereqs

import_dump "${DUMPS_PREFIX_FROM}-archive-dump" $SCHEMA_NAME

if [[ "$1" == "--first-job" ]]
then 
	run_second_phase_of_migration_first_time
else 
	run_second_phase_of_migration
fi


grep Error ${CHECKPOINT_PREFIX}.log;

HAVE_ERRORS=$?;
if [ $HAVE_ERRORS -eq 0 ]; then 
  berkeley_migration_ERRORS=${CHECKPOINT_PREFIX}_errors_${DATE};
  echo "Errors found in ${CHECKPOINT_PREFIX}.log, uploading log" "$berkeley_migration_ERRORS";
  mv ${CHECKPOINT_PREFIX}.log "$berkeley_migration_ERRORS";
  gsutil -o "$KEY_FILE_ARG" cp "$berkeley_migration_ERRORS" gs://${CHECKPOINT_BUCKET};  
else
  echo "No errors found! uploading newest local checkpoint to ${CHECKPOINT_BUCKET} bucket";
  rm -f "$MOST_RECENT_CHECKPOINT";
  DISK_CHECKPOINT=$(ls -t ${CHECKPOINT_PREFIX}-checkpoint*.json | head -n 1);
  DATE=$(date +%F);
  TODAY_CHECKPOINT=$CHECKPOINT_PREFIX-checkpoint-$DATE.json;
  mv "$DISK_CHECKPOINT" "$TODAY_CHECKPOINT";
  echo "Uploading checkpoint file" "$TODAY_CHECKPOINT";
  gsutil -o "$KEY_FILE_ARG" cp "$TODAY_CHECKPOINT" gs://$CHECKPOINT_BUCKET;

  echo "uploading migrated schema to ${DUMPS_BUCKET} bucket";
  UPLOAD_SCRIPT_NAME=${DUMPS_PREFIX_TO}-archive-dump-${DATE}_0000.sql
  su postgres -c "cd ~ && pg_dump $SCHEMA_NAME > $UPLOAD_SCRIPT_NAME";
  UPLOAD_ARCHIVE_NAME=$UPLOAD_SCRIPT_NAME.tar.gz
  mv ~postgres/$UPLOAD_SCRIPT_NAME .
  tar -czvf $UPLOAD_ARCHIVE_NAME $UPLOAD_SCRIPT_NAME;
  gsutil -o $KEY_FILE_ARG cp $UPLOAD_ARCHIVE_NAME gs://$DUMPS_BUCKET;
fi

sleep infinity
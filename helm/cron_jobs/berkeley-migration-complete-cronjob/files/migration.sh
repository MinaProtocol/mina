#!/bin/bash

echo "Starting migration cron job";

KEY_FILE_ARG="Credentials:gs_service_key_file=/gcloud/keyfile.json"

# DUMPS
DUMPS_BUCKET="${DUMPS_BUCKET:-}"

DUMPS_PREFIX_FROM="${DUMPS_PREFIX_FROM:-}"
SCHEMA_NAME_FROM="${SCHEMA_NAME_FROM:-}"

DUMPS_PREFIX_TO="${DUMPS_PREFIX_TO:-}"
SCHEMA_NAME_TO="${SCHEMA_NAME_TO:-}"

# GENESIS_LEDGER
GENESIS_LEDGER_URI="${GENESIS_LEDGER_URI:-"https://github.com/MinaProtocol/mina/raw/testing/hard-fork-internal/genesis_ledgers/devnet.json"}"

#ARCHIVE
CREATE_SCRIPT_URI="${CREATE_SCRIPT_URI:-"https://raw.githubusercontent.com/MinaProtocol/mina/berkeley/src/app/archive"}"

# PRECOMPUTED LOGS
PRECOMP_BLOCKS_BUCKET="${PRECOMP_BLOCKS_BUCKET:-}"
PRECOMPUTED_BLOCKS_DOWNLOAD_BATCH_SIZE="${PRECOMPUTED_BLOCKS_DOWNLOAD_BATCH_SIZE:-5}"
NETWORK_NAME="${NETWORK_NAME:-}"

# CHECKPOINT
CHECKPOINT_PREFIX="${CHECKPOINT_PREFIX:-}"
CHECKPOINT_BUCKET="${CHECKPOINT_BUCKET:-}"

MIGRATION_LOG="${DUMPS_PREFIX_TO:-}"

PG_CONN_STRING=postgres://postgres:postgres@localhost:5432

DATE=$(date '+%Y-%m-%d_%H%M')

FORK_STATE_HASH="${FORK_STATE_HASH:-}"
INITIAL_RUN=${INITIAL_RUN:-false} 

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

import_dump () {

    PREFIX=$1
    SCHEMA=$2


	echo "Fetching newest dump from ${DUMPS_BUCKET} starting with ${PREFIX}"

	ARCHIVE_DUMP_URI=$(gsutil ls gs://"${DUMPS_BUCKET}"/"${PREFIX}"-*.sql.tar.gz | sort -r | head -n 1);
	ARCHIVE_DUMP=$(basename "$ARCHIVE_DUMP_URI");
	ARCHIVE_SQL=$(basename "$ARCHIVE_DUMP_URI" .tar.gz);

	echo "Found lastest dump: " "$ARCHIVE_DUMP_URI" " . Downloading ...";
	gsutil  cp "$ARCHIVE_DUMP_URI" . ;
	
	tar -xzvf "$ARCHIVE_DUMP";
	
	echo "Creating schema and importing archive dump";

	psql $PG_CONN_STRING -c "CREATE DATABASE $SCHEMA";
	psql $PG_CONN_STRING/"$SCHEMA" < "$ARCHIVE_SQL";

}

# Creates target empty schema .
# Should be used on initial migration steps (when there is no existing partially migrated schema)
import_dump_first_time () {
	SCHEMA=$1

	echo "Creating ${SCHEMA} archive..."

	echo "Fetching newest schema from "

	wget -nv "${CREATE_SCRIPT_URI}"/create_schema.sql
	wget -nv "${CREATE_SCRIPT_URI}"/zkapp_tables.sql
	
	ARCHIVE_SQL=create_schema.sql

	echo "Creating schema and importing archive dump";

	psql $PG_CONN_STRING -c "CREATE DATABASE $SCHEMA";
	psql $PG_CONN_STRING/"$SCHEMA" < $ARCHIVE_SQL;
}

run_first_phase_of_migration() {


	echo "Starting migration Phase 1";

	echo "Downloading genesis_ledger";
	wget -nv $GENESIS_LEDGER_URI -O genesis_ledger.json
	
	echo "Running berkeley migration app";
	
	
	if [ -z "${FORK_STATE_HASH}" ]; then
		mina-berkeley-migration --mainnet-archive-uri ${PG_CONN_STRING}/"${SCHEMA_NAME_FROM}" --migrated-archive-uri ${PG_CONN_STRING}/"${SCHEMA_NAME_TO}" --batch-size ${PRECOMPUTED_BLOCKS_DOWNLOAD_BATCH_SIZE} --config-file genesis_ledger.json --blocks-bucket "$PRECOMP_BLOCKS_BUCKET" --network "$NETWORK_NAME" | tee "${MIGRATION_LOG}".log
	else
		mina-berkeley-migration --mainnet-archive-uri ${PG_CONN_STRING}/"${SCHEMA_NAME_FROM}" --migrated-archive-uri ${PG_CONN_STRING}/"${SCHEMA_NAME_TO}" --batch-size ${PRECOMPUTED_BLOCKS_DOWNLOAD_BATCH_SIZE} --config-file genesis_ledger.json --blocks-bucket "$PRECOMP_BLOCKS_BUCKET" --network "$NETWORK_NAME" --fork-state-hash $FORK_STATE_HASH | tee "${MIGRATION_LOG}".log
	fi
    echo "Done running berkeley migration app";

}

run_second_phase_of_migration() {
	INPUT_FILE=$1

	echo "Running replayer in migration mode";
	
	mina-replayer --migration-mode --archive-uri ${PG_CONN_STRING}/"${SCHEMA_NAME_TO}" --input-file "$INPUT_FILE" --checkpoint-interval 100 --checkpoint-file-prefix "$CHECKPOINT_PREFIX" | tee "${CHECKPOINT_PREFIX}".log
	
	echo "Done running replayer in migration mode";
}

run_second_phase_of_migration_first_time() {

	echo "Starting migration Phase 2";

	echo "Downloading genesis_ledger";
	wget -nv https://github.com/MinaProtocol/mina/raw/testing/hard-fork-internal/genesis_ledgers/devnet.json -O ledger.json
	
	cat ledger.json | jq '.ledger.accounts' > accounts.json
	echo '{ "genesis_ledger": { "accounts": '$(cat accounts.json)' } }' | jq > initial_config.json
	
	run_second_phase_of_migration initial_config.json
}

run_second_phase_of_migration_based_on_checkpoint () {

	echo "Starting migration Phase 2";

	echo "Downloading newest checkpoint";
    MOST_RECENT_CHECKPOINT_URI=$(gsutil -o "$KEY_FILE_ARG" ls gs://"$CHECKPOINT_BUCKET"/"$CHECKPOINT_PREFIX"-checkpoint-*.json | sort -r | head -n 1);
    MOST_RECENT_CHECKPOINT=$(basename "$MOST_RECENT_CHECKPOINT_URI");
    gsutil -o "$KEY_FILE_ARG" cp "$MOST_RECENT_CHECKPOINT_URI" . ;

	run_second_phase_of_migration $MOST_RECENT_CHECKPOINT
}

upload_error () {
  PREFIX=$1
  BUCKET=$2

  ERROR_FILE=${PREFIX}_errors_${DATE}.log;
  echo "Found errors, uploading log" "$ERROR_FILE" "to" "$BUCKET";
  mv "${PREFIX}".log "$ERROR_FILE";
  gsutil -o "$KEY_FILE_ARG" cp "$ERROR_FILE" gs://"$BUCKET"/"$ERROR_FILE";
}

upload_replayer_checkpoint () {
  echo "No errors found! uploading newest local checkpoint to ${CHECKPOINT_BUCKET} bucket";
  COUNT_CHECKPOINTS=$(ls -t "${CHECKPOINT_PREFIX}"-checkpoint*.json 2> /dev/null | wc -l)
  
  if [ "$PHASE_2_INITIAL_RUN" == "true" ]; then
	
	if [ "$COUNT_CHECKPOINTS" -eq "0" ]; then
		echo " There are no new checkpoints. It means that no transactions are archived before \
current and last migration or there are no canoncial block apart from genesis (when FORK_STATE_HASH env var is empty)"
		return 
    fi

  else 
	
	if [ "$COUNT_CHECKPOINTS" -eq "1" ]; then
	  echo " There are no new checkpoints apart from the on downloaded before migration \
It means that no transactions are archived before this and last migration "
	  return 
	else
	  rm -f "$MOST_RECENT_CHECKPOINT";	
	fi
	
  fi
  
  DISK_CHECKPOINT=$(ls -t "${CHECKPOINT_PREFIX}"-checkpoint*.json | head -n 1);
  TODAY_CHECKPOINT=$CHECKPOINT_PREFIX-checkpoint-${DATE}.json;
  mv "$DISK_CHECKPOINT" "$TODAY_CHECKPOINT";
  echo "Uploading checkpoint file" "$TODAY_CHECKPOINT";
  gsutil -o "$KEY_FILE_ARG" cp "$TODAY_CHECKPOINT" gs://"$CHECKPOINT_BUCKET";
} 

upload_dump () {
  echo "No errors found! uploading migrated schema to ${DUMPS_BUCKET} bucket"
  UPLOAD_SCRIPT_NAME=${DUMPS_PREFIX_TO}-archive-dump-${DATE}.sql
  pg_dump $PG_CONN_STRING/"$SCHEMA_NAME_TO" > "$UPLOAD_SCRIPT_NAME"
  UPLOAD_ARCHIVE_NAME=$UPLOAD_SCRIPT_NAME.tar.gz
  tar -czvf "$UPLOAD_ARCHIVE_NAME" "$UPLOAD_SCRIPT_NAME"
  gsutil -o "$KEY_FILE_ARG" cp "$UPLOAD_ARCHIVE_NAME" gs://"$DUMPS_BUCKET"
}

determine_migration_state () {
	MIGRATED_DUMPS_COUNT=$(gsutil ls gs://${DUMPS_BUCKET}/${DUMPS_PREFIX_FROM}-*.sql.tar.gz 2> /dev/null | wc -l)
	if [ "$MIGRATED_DUMPS_COUNT" -eq 0 ]; then 
		echo "No migrated dumps found. Assuming this is phase 1 initial run"
		PHASE_1_INITIAL_RUN=true
	else
		echo "Already migrated dumps found. Assuming this is phase 1 incremental run"
		PHASE_1_INITIAL_RUN=false
	fi

	CHECKPOINTS_COUNT=$(gsutil -o "$KEY_FILE_ARG" ls gs://"$CHECKPOINT_BUCKET"/"$CHECKPOINT_PREFIX"-checkpoint-*.json 2> /dev/null | wc -l )
	if [ "$CHECKPOINTS_COUNT" -eq 0 ]; then 
		echo "No migrated checkpoints found. Assuming this is phase 2 initial run"
		PHASE_2_INITIAL_RUN=true
	else
		echo "Already migrated dumps found. Assuming this is phase 2 incremental run"
		PHASE_2_INITIAL_RUN=false
	fi
}


service postgresql start;
su postgres -c "echo ALTER USER postgres WITH PASSWORD \'postgres\' | psql";

install_prereqs

determine_migration_state

import_dump "${DUMPS_PREFIX_FROM}-archive-dump" "$SCHEMA_NAME_FROM"

if [ "$PHASE_1_INITIAL_RUN" == "true" ]; then
	import_dump_first_time "$SCHEMA_NAME_TO"
else 
	import_dump "${DUMPS_PREFIX_TO}-archive-dump" "$SCHEMA_NAME_TO"	
fi

run_first_phase_of_migration

grep Error "${MIGRATION_LOG}".log;
HAVE_ERRORS=$?;
	
if [ $HAVE_ERRORS -eq 0 ]; then 
	upload_error "${MIGRATION_LOG}" "${CHECKPOINT_BUCKET}"
	echo "first phase of migration ended with error.. second phase won't be ran. Exiting..."
	exit 1
fi

if [ "$PHASE_2_INITIAL_RUN" == "true" ]; then
	run_second_phase_of_migration_first_time
else
	run_second_phase_of_migration_based_on_checkpoint	
fi

grep Error "${CHECKPOINT_PREFIX}".log;
HAVE_ERRORS=$?;
	
if [ $HAVE_ERRORS -eq 0 ]; then 
	upload_error "${MIGRATION_LOG}" "${CHECKPOINT_BUCKET}"
	echo "second phase of migration ended with error.. won't upload any artifacts. Exiting..."
	exit 1
fi

upload_replayer_checkpoint
upload_dump

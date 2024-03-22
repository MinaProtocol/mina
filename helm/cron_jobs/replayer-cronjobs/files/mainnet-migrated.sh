# Function to handle errors
error_exit() {
    echo "Error: $1" 1>&2
    exit 1
}

# Updating package lists
echo "Starting replayer cron job"
apt update || error_exit "Failed to update package lists"

# Installing libjemalloc2
echo "Installing libjemalloc2"
apt-get -y install libjemalloc2 || error_exit "Failed to install libjemalloc2"

# Installing dependencies for gsutil
echo "Installing gsutil dependencies"
apt-get -y install apt-transport-https ca-certificates gnupg curl || error_exit "Failed to install gsutil dependencies"

# Adding Google Cloud SDK repository
echo "Adding Google Cloud SDK repository"
echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list || error_exit "Failed to add Google Cloud SDK repo"

# Adding Google Cloud SDK package key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - || error_exit "Failed to add Google Cloud SDK key"

# Updating package lists and installing Google Cloud CLI
apt-get update && apt-get install -y google-cloud-cli || error_exit "Failed to install Google Cloud CLI"

# Fetching the latest archive dump URI
ARCHIVE_DUMP_URI=$(gsutil -o Credentials:gs_service_key_file=/gcloud/keyfile.json ls gs://mina-archive-dumps/mainnet-migrated-archive-dump-*.sql.tar.gz | sort -r | head -n 1) || error_exit "Failed to fetch archive dump URI"
ARCHIVE_DUMP=$(basename "$ARCHIVE_DUMP_URI")
ARCHIVE_SQL=$(basename "$ARCHIVE_DUMP_URI" .tar.gz)
echo "Getting archive dump $ARCHIVE_DUMP_URI"
gsutil -o Credentials:gs_service_key_file=/gcloud/keyfile.json cp "$ARCHIVE_DUMP_URI" . || error_exit "Failed to copy archive dump"

# Fetching the most recent checkpoint URI
MOST_RECENT_CHECKPOINT_URI=$(gsutil -o Credentials:gs_service_key_file=/gcloud/keyfile.json ls gs://mainnet-migrated-checkpoints/archive-migration-checkpoint-*.json | sort -r | head -n 1) || error_exit "Failed to fetch checkpoint URI"
MOST_RECENT_CHECKPOINT=$(basename "$MOST_RECENT_CHECKPOINT_URI")
echo "Getting replayer checkpoint file $MOST_RECENT_CHECKPOINT"
gsutil -o Credentials:gs_service_key_file=/gcloud/keyfile.json cp "$MOST_RECENT_CHECKPOINT_URI" . || error_exit "Failed to copy checkpoint file"

# Starting Postgresql
echo "Starting Postgresql"
service postgresql start || error_exit "Failed to start Postgresql"

# Importing archive dump
echo "Importing archive dump"
tar -xzvf "$ARCHIVE_DUMP" || error_exit "Failed to extract archive dump"
cat "$ARCHIVE_SQL" | grep -v "CREATE DATABASE" > archive.sql
mv archive.sql "$ARCHIVE_SQL"
mv "$ARCHIVE_SQL" ~postgres/ || error_exit "Failed to move SQL file"

# Cleaning up
echo "Deleting archive dump"
rm -f "$ARCHIVE_DUMP" || error_exit "Failed to delete archive dump"

# Executing PostgreSQL commands
su postgres -c "cd ~ && echo ALTER USER postgres WITH PASSWORD \\\$\$ foobar \\\$\$ | psql" || error_exit "Failed to alter PostgreSQL user password"
su postgres -c "cd ~ && echo CREATE DATABASE archive | psql" || error_exit "Failed to create database"
su postgres -c "cd ~ && psql < \"$ARCHIVE_SQL\"" || error_exit "Failed to import data into PostgreSQL"

# Cleaning up SQL file
echo "Deleting archive SQL file"
su postgres -c "cd ~ && rm -f \"$ARCHIVE_SQL\"" || error_exit "Failed to delete SQL file"

# Running the replayer
echo "Running replayer"
mina-replayer --archive-uri postgres://postgres:%20foobar%20@localhost/archive --input-file \"$MOST_RECENT_CHECKPOINT\" --continue-on-error --output-file /dev/null --checkpoint-interval 50 > replayer.log || error_exit "Replayer execution failed"
echo "Done running replayer"

# Cleaning up checkpoint file
rm -f "$MOST_RECENT_CHECKPOINT" || error_exit "Failed to delete checkpoint file"

# Handling and uploading new checkpoint
DISK_CHECKPOINT=$(ls -t replayer-checkpoint*.json | head -n 1) || error_exit "Failed to find disk checkpoint"
DATE=$(date +%F)
TODAY_CHECKPOINT=archive-migration-checkpoint-$DATE.json
mv "$DISK_CHECKPOINT" "$TODAY_CHECKPOINT" || error_exit "Failed to rename checkpoint file"
echo "Uploading checkpoint file $TODAY_CHECKPOINT"
gsutil -o Credentials:gs_service_key_file=/gcloud/keyfile.json cp "$TODAY_CHECKPOINT" gs://mainnet-migrated-checkpoints/"$TODAY_CHECKPOINT" || error_exit "Failed to upload checkpoint file"

# Checking for errors in the replayer log
echo "Replayer errors:"
grep Error replayer.log
HAVE_ERRORS=$?
if [ $HAVE_ERRORS -eq 0 ]; then
    REPLAYER_ERRORS=berkeley_replayer_errors_${DATE}
    echo "The replayer found errors, uploading log $REPLAYER_ERRORS"
    mv replayer.log "$REPLAYER_ERRORS"
    gsutil -o Credentials:gs_service_key_file=/gcloud/keyfile.json cp "$REPLAYER_ERRORS" gs://mainnet-migrated-checkpoints/"$REPLAYER_ERRORS" || error_exit "Failed to upload error log"
fi

# Script complete
echo "Replayer cron job completed successfully"

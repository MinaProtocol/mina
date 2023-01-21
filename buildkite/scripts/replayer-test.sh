#!/bin/bash

TEST_DIR=/var/lib/mina/replayer-test/
PGPASSWORD=arbitraryduck

set -eo pipefail

echo "Updating apt, installing packages"
apt-get update
# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

echo "Starting Postgresql service"
service postgresql start

echo "Populating archive database"
cd ~postgres
su postgres -c psql < $TEST_DIR/archive_db.sql
echo "ALTER USER postgres PASSWORD '$PGPASSWORD';" | su postgres -c psql
cd /workdir

echo "Running replayer"
mina-replayer --archive-uri postgres://postgres:$PGPASSWORD@localhost:5432/archive \
	      --input-file $TEST_DIR/input.json --output-file /dev/null

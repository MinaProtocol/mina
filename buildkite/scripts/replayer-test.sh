#!/bin/bash

TEST_DIR=/workdir/src/app/replayer/test
PGPASSWORD=arbitraryduck

set -eo pipefail

echo "Updating apt, installing packages"
apt-get update
# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

# time zone = US Pacific
apt-get install -y tzdata git postgresql apt-transport-https ca-certificates curl

git config --global --add safe.directory /workdir

echo "Generating locale for Postgresql"
locale-gen en_US.UTF-8
sudo -u postgres locale-gen en_US.UTF-8

echo "Starting Postgresql service"
service postgresql start

echo "Populating archive database"
cd ~postgres
sudo -u postgres psql < $TEST_DIR/archive_db.sql
echo "ALTER USER postgres PASSWORD '$PGPASSWORD';" | sudo -u postgres -c psql
cd /workdir

echo "Running replayer"
mina-replayer --archive-uri postgres://postgres:$PGPASSWORD@localhost:5432/archive \
	      --input-file $TEST_DIR/input.json --output-file /dev/null

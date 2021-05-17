#!/bin/bash

TEST_DIR=/workdir/src/app/replayer/test
PGPASSWORD=arbitraryduck

set -eo pipefail

echo "Updating apt, installing packages"
apt-get update
# time zone = US Pacific
/bin/echo -e "12\n10" | apt-get install -y tzdata
apt-get install -y git postgresql apt-transport-https ca-certificates curl

export DUNE_PROFILE=devnet

source buildkite/scripts/export-git-env-vars.sh
# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

echo "deb [trusted=yes] http://packages.o1test.net alpha buster" | tee /etc/apt/sources.list.d/coda.list
apt-get update

echo "Installing archive node package: mina-archive-devnet=${VERSION}"
apt-get install --allow-downgrades -y mina-archive-devnet=${VERSION}

echo "Generating locale for Postgresql"
locale-gen en_US.UTF-8

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

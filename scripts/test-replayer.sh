#!/bin/sh

# test replayer on known archive db

REPLAYER_DIR=src/app/replayer
DB=archive_db

DOCKER_IMAGE=12.4-alpine
CONTAINER_FILE=docker.container

PG_PORT=5432
PG_PASSWORD=somepassword
PG_CONN=postgres://postgres:$PG_PASSWORD@localhost:$PG_PORT/$DB

# -v mounts dir with Unix socket on host
echo "Starting docker with Postgresql"
docker run \
       --name replayer-postgres -d -v /var/run/postgresql:/var/run/postgresql -p $PG_PORT:$PG_PORT \
       -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=$PG_PASSWORD -e POSTGRES_DB=$DB postgres:$DOCKER_IMAGE > $CONTAINER_FILE

# wait for Postgresql to become available
sleep 5

echo "Populating archive database"
psql -U postgres -d $DB < $REPLAYER_DIR/test/archive_db.sql

# build with `dev`, because the archive db was created by using Rosetta's `start.sh`, which
# uses that profile; using `make replayer` would generate different ledger hashes
echo "Running replayer"
dune b $REPLAYER_DIR/replayer.exe --profile=dev

./_build/default/src/app/replayer/replayer.exe --archive-uri $PG_CONN --input-file $REPLAYER_DIR/test/input.json --output-file /dev/null

RESULT=$?

echo "Killing, removing docker container"
CONTAINER=`cat docker.container`
for action in kill rm; do
    docker container $action $CONTAINER
done

rm -f $CONTAINER_FILE

if [ $RESULT = 0 ]; then
    echo SUCCEEDED
else
    echo FAILED
fi

exit $RESULT

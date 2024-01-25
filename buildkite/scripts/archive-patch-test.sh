#!/bin/bash

TEST_DIR=/workdir/src/app/replayer/

set -eox pipefail

echo "Updating apt, installing packages"
apt-get update

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

apt-get install -y git apt-transport-https ca-certificates curl wget

git config --global --add safe.directory $BUILDKITE_BUILD_CHECKOUT_PATH

source buildkite/scripts/export-git-env-vars.sh

PG_DB=archive
PG_PORT=5433
PG_PASSWORD=somepassword
PG_DOCKER_NAME=patch-archive-postgres
PG_DOCKER_TAG=12.4-alpine
CONTAINER_FILE=docker.container
NETWORK=local-network




function cleanup () {
    CONTAINER=`cat $CONTAINER_FILE`

    if [[ ! -z $CONTAINER ]] ; then
	echo "Killing, removing docker container"
	for action in kill rm; do
	    docker container $action $CONTAINER
	done
    fi

    rm -f $CONTAINER_FILE
}

docker network create $NETWORK || true

# -v mounts dir with Unix socket on host
echo "Starting docker with Postgresql"
docker run \
       --network $NETWORK \
       --volume $BUILDKITE_BUILD_CHECKOUT_PATH:/workdir \
       --name $PG_DOCKER_NAME -d -p $PG_PORT:5432 \
       -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=$PG_PASSWORD -e POSTGRES_DB=$DB postgres:$DOCKER_IMAGE > $CONTAINER_FILE

trap "cleanup; exit 1" SIGINT

# wait for Postgresql to become available
sleep 5

echo "Populating archive database"

NETWORK_GATEWAY=$(docker network inspect -f "{{(index .IPAM.Config 0).Gateway}}" $NETWORK)

PG_CONN="postgres://postgres:$PG_PASSWORD@$NETWORK_GATEWAY:$PG_PORT/$DB"


docker exec $PG_DOCKER_NAME psql $PG_CONN -f $TEST_DIR/test/archive_db.sql

docker run --network $NETWORK --volume $BUILDKITE_BUILD_CHECKOUT_PATH:/workdir gcr.io/o1labs-192920/mina-archive:$MINA_DOCKER_TAG /workdir/scripts/patch-archive-test.sh -d $TEST_DIR -a mina-replayer -p $PG_CONN

cleanup

#!/bin/bash

MODE="run"

while [ $# -gt 0 ]; do
  case "$1" in
  -b|--bootstrap-only*)
    MODE="bootstrap-only"
    echo "Bootstrap only mode enabled. Script will setup databases but won't run tests"
    ;;
  esac
  shift
done

git config --global --add safe.directory $BUILDKITE_BUILD_CHECKOUT_PATH

POSTGRES_PORT=5555
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DOCKER=postgres:12-bullseye

if [ $MODE == "run" ]; then 
    NETWORK_PARAM="--network hardfork"
else
    NETWORK_PARAM=""
fi


wget https://raw.githubusercontent.com/MinaProtocol/mina/c980ba8/src/app/archive/create_schema.sql

docker stop postgres || true && docker rm postgres || true
docker network create hardfork || true
docker run --name postgres $NETWORK_PARAM -p $POSTGRES_PORT:5432 -e POSTGRES_USER=$POSTGRES_USER -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD -d $POSTGRES_DOCKER  -c log_statement=mod

export NETWORK_GATEWAY=$(docker network inspect -f "{{(index .IPAM.Config 0).Gateway}}" hardfork)

echo "Waiting for db to init..."
while true; do
    if [[ "$(docker container exec postgres pg_isready -U postgres)" == *"accepting connections"* ]]; then
        break;
    fi
    sleep 5
done

if [ $MODE == "run" ]; then
    source buildkite/scripts/export-git-env-vars.sh
    TEST_SUITE_DOCKER=gcr.io/o1labs-192920/mina-test-suite:$MINA_DOCKER_TAG
    jq  '.db.host |= "'"$NETWORK_GATEWAY"'"' src/test/hardfork/archive_migration_tests/ci.json | \
    jq  '.reference.volume_bind |= "'"$BUILDKITE_BUILD_CHECKOUT_PATH"'/hardfork_tests"' > ci.json
   
    docker run --volume "/var/run/docker.sock:/var/run/docker.sock" --volume $BUILDKITE_BUILD_CHECKOUT_PATH:/workdir --entrypoint mina-archive-migration-tests $TEST_SUITE_DOCKER test mainnet_migration --env /workdir/ci.json 
fi
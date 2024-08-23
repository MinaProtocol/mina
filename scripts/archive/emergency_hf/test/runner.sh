#!/bin/bash

DOCKER_IMAGE=12.4-alpine
CONTAINER_FILE=docker.container

PG_PORT=5433
PG_PASSWORD=somepassword

function cleanup () {
    CONTAINER=$(cat $CONTAINER_FILE)

    if [[ -n $CONTAINER ]] ; then
	echo "Killing, removing docker container"
	for action in kill rm; do
	    docker container $action "$CONTAINER"
	done
    fi

    rm -f $CONTAINER_FILE
}

DOCKET_NETWORK=emergency_hf
docker network create $DOCKET_NETWORK || true

# -v mounts dir with Unix socket on host
echo "Starting docker with Postgresql"
docker run \
       --network $DOCKET_NETWORK \
       --volume "$BUILDKITE_BUILD_CHECKOUT_PATH":/workdir \
       --name replayer-postgres -d -p $PG_PORT:5432 \
       -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=$PG_PASSWORD -e POSTGRES_DB="$DB" postgres:$DOCKER_IMAGE > $CONTAINER_FILE

trap "cleanup; exit 1" SIGINT

# wait for Postgresql to become available
sleep 5

echo "Populating archive databases"

NETWORK_GATEWAY=$(docker network inspect -f "{{(index .IPAM.Config 0).Gateway}}" $DOCKET_NETWORK)

PG_CONN="postgres://postgres:$PG_PASSWORD@$NETWORK_GATEWAY:$PG_PORT"


function assert () {
    local expected="$1"; local name="$2"; local db_name=$3;

    ACTUAL=$(docker exec replayer-postgres psql "$PG_CONN/$db_name" -AF '->' -t -c "select state_hash,chain_status from blocks order by state_hash asc" )
    compare "$expected" "$ACTUAL" "$name"
}

function compare () {
    local left="$1"; local right="$2"; local test_name=$3;

    if [ "$left" = "$right" ]; then
        echo "PASSED: actual vs expected blocks comparision for $test_name"
    else
        echo "FAILED: comparision failed for $test_name"
        echo "EXPECTED:"
        echo "$left"
        echo "ACTUAL:"
        echo "$right"
        exit 1
    fi
}

function test_fork_on_canonical_in_the_middle_assert() {
    local __db_name=$1

    ./scripts/archive/emergency_hf/convert_chain_to_canonical.sh "$PG_CONN"/"$__db_name" 'C' 2

    EXPECTED="A->canonical
B->canonical
C->canonical
D->orphaned
E->orphaned"

    assert "$EXPECTED" "$FUNCNAME" "$__db_name"
}


function test_fork_on_new_network_assert() {
    local __db_name=$1

    ./scripts/archive/emergency_hf/convert_chain_to_canonical.sh "$PG_CONN"/"$__db_name" 'C' 2

    EXPECTED="A->canonical
B->canonical
C->canonical
D->orphaned
E->orphaned"

    assert "$EXPECTED" "$FUNCNAME" "$__db_name"
}

function test_fork_on_last_canonical_assert() {
    local __db_name=$1

    ./scripts/archive/emergency_hf/convert_chain_to_canonical.sh "$PG_CONN"/"$__db_name" 'C' 2

    EXPECTED="A->canonical
B->canonical
C->canonical
D->orphaned
E->orphaned"

    assert "$EXPECTED" "$FUNCNAME" "$__db_name"
}

function test_fork_on_orphaned_assert() {
    local __db_name=$1

    ./scripts/archive/emergency_hf/convert_chain_to_canonical.sh "$PG_CONN"/"$__db_name" 'B' 2

    EXPECTED="A->canonical
B->canonical
C->orphaned
D->orphaned
E->orphaned"

    assert "$EXPECTED" "$FUNCNAME" "$__db_name"
}

function test_fork_on_pending_assert() {
    local __db_name=$1

    ./scripts/archive/emergency_hf/convert_chain_to_canonical.sh "$PG_CONN"/"$__db_name" 'C' 2

    EXPECTED="A->canonical
B->orphaned
C->canonical
D->orphaned"

    assert "$EXPECTED" "$FUNCNAME" "$__db_name"
}

function test_surrounded_by_pendings_assert() {
    local __db_name=$1

    ./scripts/archive/emergency_hf/convert_chain_to_canonical.sh "$PG_CONN"/"$__db_name" 'C' 2

    EXPECTED="A->canonical
B->orphaned
C->canonical
D->orphaned
E->orphaned"

    assert "$EXPECTED" "$FUNCNAME" "$__db_name"
}

for file in ./scripts/archive/emergency_hf/test/*.sql; do
    DB_NAME=$(basename "$file" .sql)
    
    docker exec replayer-postgres psql "$PG_CONN" -c "create database $DB_NAME"
    docker exec replayer-postgres psql "$PG_CONN/$DB_NAME" -f /workdir/scripts/archive/emergency_hf/test/"$DB_NAME".sql

    "${DB_NAME}_assert" "$DB_NAME"
done
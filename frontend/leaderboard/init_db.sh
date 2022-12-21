#!/usr/bin/env bash
set -x
set -eo pipefail

# Check if a custom user has been set, otherwise default to 'postgres'
DB_USER="${POSTGRES_USER:=postgres}"
# Check if a custom password has been set, otherwise default to 'password'
DB_PASSWORD="${POSTGRES_PASSWORD:=password}"
# Check if a custom database name has been set, otherwise default to 'archive'
DB_NAME="${POSTGRES_DB:=archive}"
# Check if a custom port has been set, otherwise default to '5432'
DB_PORT="${POSTGRES_PORT:=5432}"
# Check if a custom host has been set, otherwise default to 'localhost'
DB_HOST="${POSTGRES_HOST:=localhost}"

CONTAINER_NAME="postgres_$(date '+%s')"
PG_DUMP="berkeley_archive.sql"

if [ ! -f "./data/${PG_DUMP}" ]
then
	echo "SQL dump not found. Make sure you have a sql dump at the path: $(pwd)/data/${PG_DUMP}"
  exit 1
fi


# if a postgres container is running, print instructions to kill it and exit
RUNNING_POSTGRES_CONTAINER=$(docker ps --filter 'name=postgres' --format '{{.ID}}')
if [[ -n $RUNNING_POSTGRES_CONTAINER ]]; then
  echo >&2 "there is a postgres container already running, kill it with"
  echo >&2 "    docker kill ${RUNNING_POSTGRES_CONTAINER}"
  docker kill ${RUNNING_POSTGRES_CONTAINER}
fi
# Launch postgres using Docker
docker run \
    -e POSTGRES_USER=${DB_USER} \
    -e POSTGRES_PASSWORD=${DB_PASSWORD} \
    -e POSTGRES_DB=${DB_NAME} \
    -p "${DB_PORT}":5432 \
    -v "$(pwd)/data/${PG_DUMP}":"/data/${PG_DUMP}" \
    -d \
    --name ${CONTAINER_NAME} \
    postgres -N 1000
    # ^ Increased maximum number of connections for testing purposes

# Keep pinging Postgres until it's ready to accept commands
until PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -U "${DB_USER}" -p "${DB_PORT}" -d "postgres" -c '\q'; do
  >&2 echo "Postgres is still unavailable - sleeping"
  sleep 1
done

>&2 echo "Postgres is up and running on port ${DB_PORT}!"

# zkapps_monitor role creation seems to be missing from the sql dump. We'll create it here.
>&2 echo "Creating zkapps_monitor role..."
docker exec \
	-d \
	${CONTAINER_NAME} \
	bash -c "psql -U ${DB_USER} CREATE USER zkapps_monitor"

>&2 echo "Creating ${DB_NAME} database..."
# Import the SQL dump from the data directory
docker exec \
	-d \
	${CONTAINER_NAME} \
	bash -c "psql -U ${DB_USER} ${DB_NAME} < /data/${PG_DUMP}"

# Export the connection string as an environment variable
export DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}
echo DATABASE_URL
>&2 echo "Postgres has been initalized and is ready to go!"
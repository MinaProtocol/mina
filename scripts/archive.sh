HASURA_PORT=9000

if [ -z "$STORAGE_DIRECTORY" ]; then
  STORAGE_DIRECTORY=~/.coda-config/client_storage
fi

if [ -z "$POSTGRES_PORT" ]; then
  POSTGRES_PORT=1337
fi

if [ -z "$DATABASE_NAME" ]; then
  DATABASE_NAME=coda
fi

if [ -z "$ADMIN" ]; then
  ADMIN=$(whoami)
fi

if [ -z "$HASURA_PORT" ]; then
  HASURA_PORT=9000
fi

init () {
    pg_ctl init -D $STORAGE_DIRECTORY;
    pg_ctl -o "-F -p $POSTGRES_PORT" start -D $STORAGE_DIRECTORY;
    createdb coda $STORAGE_DIRECTORY -p $POSTGRES_PORT;
    psql -p $POSTGRES_PORT -d $DATABASE_NAME -f src/app/archive/create_schema.sql;
    pg_ctl stop -D $STORAGE_DIRECTORY
}

start() {
    pg_ctl -o "-F -p $POSTGRES_PORT" start -D $STORAGE_DIRECTORY;
    docker run -p $HASURA_PORT:8080 \
        -e HASURA_GRAPHQL_DATABASE_URL=postgres://$ADMIN:@host.docker.internal:$POSTGRES_PORT/$DATABASE_NAME \
        -e HASURA_GRAPHQL_ENABLE_CONSOLE=true \
        hasura/graphql-engine:v1.0.0-beta.6
}

stop () {
    pg_ctl stop -D $STORAGE_DIRECTORY
}

flush () {
    rm -rf $STORAGE_DIRECTORY    
}

update_graphql () {
  python scripts/introspection_query.py > src/app/archive/graphql_schema.json
}

set -x #echo on
set -eu

if [[ $1 =~ ^(init|start|stop|flush)$ ]]; then
  "$@"
else
  echo "Invalid subcommand $1" >&2
  exit 1
fi
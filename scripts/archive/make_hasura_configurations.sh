#!/bin/bash
# Makes a database queryable through graphql
set -e

sleep 5

# Sets the default path to the directory you run the command, which is assumed to be the coda directory
if [[ "$CODA_DIRECTORY_PATH" -eq "" ]]; then
    CODA_DIRECTORY_PATH=$(pwd)
fi

curl -d'{"type":"replace_metadata", "args":'$(cat scripts/archive/metadata.json)'}' \
    http://localhost:$HASURA_PORT/v1/query

# Generates the graphql query types for OCaml
mkdir $CODA_DIRECTORY_PATH/scripts/archive/output
python3 $CODA_DIRECTORY_PATH/scripts/introspection_query.py --port $HASURA_PORT --uri /v1/graphql --headers X-Hasura-Role:user \
    | python3 $CODA_DIRECTORY_PATH/scripts/archive/change_constraint.py >> $CODA_DIRECTORY_PATH/scripts/archive/output/graphql_schema.json

echo "Finished getting introspection data"
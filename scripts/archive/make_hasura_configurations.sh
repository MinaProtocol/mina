# Makes a database queryable through graphql
set -e

sleep 5

curl -d'{"type":"replace_metadata", "args":'$(cat scripts/archive/metadata.json)'}' \
    http://localhost:$HASURA_PORT/v1/query

mkdir -p output/
# Generates the graphql query types for OCaml
python3 /scripts/introspection_query.py --port $HASURA_PORT --uri /v1/graphql --headers X-Hasura-Role:user \
    | python3 /scripts/archive/change_constraint.py > /scripts/archive/output/graphql_schema.json

echo "Finished getting introspection data"
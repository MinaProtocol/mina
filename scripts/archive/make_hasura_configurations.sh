# Makes a database queryable through graphql
set -e

opam config exec -- dune build scripts/archive/ocaml/stitch_introspection.exe

sleep 10

curl -d'{"type":"replace_metadata", "args":'$(cat scripts/archive/metadata.json)'}' \
    http://localhost:9000/v1/query

mkdir -p output/
# Generates the graphql query types for OCaml
python3 scripts/introspection_query.py --port 9000 --uri /v1/graphql --headers X-Hasura-Role:user \
    | _build/default/scripts/archive/ocaml/sttch_introspection.exe \
    > output/graphql_schema.json

echo "Finished getting introspection data"
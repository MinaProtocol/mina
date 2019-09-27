# Makes a database queryable through graphql
sleep 5

set -x

curl -d'{"type":"replace_metadata", "args":'$(cat /metadata.json)'}' http://localhost:9000/v1/query

export STITCH_EXE=archive-ocaml-script/stitch_introspection.exe

dune b archive-ocaml-script/stitch_introspection.exe

chmod 755 _build/default/

# Generates the graphql query types for OCaml
python /introspection_query.py --port 9000 --uri /v1/graphql --headers X-Hasura-Role:user \
    | _build/default/archive-ocaml-script/stitch_introspection.exe \
    > /output/graphql_schema.json

echo "Finished getting introspection data"
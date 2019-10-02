# Makes a database queryable through graphql
opam config exec -- dune build scripts/archive/ocaml/stitch_introspection.exe

for i in `seq 1 10`;
do
    # TODO: Install netcat to docker toolchain
    nc -z 127.0.0.1 9000 && echo "Received successful connection to Hasura" && break
    echo "Waiting for connection from Hasura"
    sleep 1
done
if [ $i -eq 10 ]
then
    echo "Took to long for seeing Hasura is up. Did you run the Hasura docker container?" && exit 1
fi

curl -d'{"type":"replace_metadata", "args":'$(cat scripts/archive/metadata.json)'}' \
    http://localhost:9000/v1/query

mkdir -p scripts/archive/output/
# Generates the graphql query types for OCaml
python3 scripts/introspection_query.py --port 9000 --uri /v1/graphql --headers X-Hasura-Role:user \
    | _build/default/scripts/archive/ocaml/stitch_introspection.exe \
    > scripts/archive/output/graphql_schema.json

echo "Finished getting introspection data"
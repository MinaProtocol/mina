#!/bin/bash

# Argument 1: is the query selector for the zkapp_command
# Argument 2: is the zkApp command json
# Argument 3: is the GraphQL URI

set -x

curl \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$(printf '{ "query": "mutation($input: SendZkappInput!) { sendZkapp(input: $input) %s }" , "variables": { "input": { "zkappCommand": %s } } }' "$1" "$2")" $3

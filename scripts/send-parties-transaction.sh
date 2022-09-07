#!/bin/bash

# Argument 1: is the query selector for the zkapp_command
# Argument 2: is the zkapp_command json
# Argument 3: is the GraphQL URI

set -x

curl \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$(printf '{ "query": "mutation($input: SendZkappInput!) { sendZkapp(input: $input) %s }" , "variables": { "input": { "zkapp_command": %s } } }' "$1" "$2")" $3

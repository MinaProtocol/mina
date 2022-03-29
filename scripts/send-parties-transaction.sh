#!/bin/bash

# Argument 1: is the query selector for the parties
# Argument 2: is the parties json
# Argument 3: is the GraphQL URI

set -x

curl \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$(printf '{ "query": "mutation($parties: SendSnappInput!) { sendSnapp(input: $parties) { %s } }" , "variables": { "parties": %s } }' "$1" "$2")" $3

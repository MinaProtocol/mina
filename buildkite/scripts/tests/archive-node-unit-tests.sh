#!/bin/bash

set -euo pipefail

if [[ ! -f dune-project ]]; then
    echo "Error: This script must be run from the root of the repository (where 'dune-project' exists)."
    exit 1
fi

user="$1"
password="$2"
db="$3"
command_key="$4"

if [[ -z "$user" || -z "$password" || -z "$db" || -z "$command_key" ]]; then
    echo "Usage: $0 <user> <password> <db> <command_key>"
    exit 1
fi

eval $(opam config env) 

echo "Setting up database for archive node tests..."

source ./buildkite/scripts/setup-database-for-archive-node.sh ${user} ${password} ${db} 

echo "Database setup complete, accessible via $MINA_TEST_POSTGRES . Running archive node unit tests..."
dune runtest src/app/archive 

./buildkite/scripts/upload-partial-coverage-data.sh ${command_key} "dev"
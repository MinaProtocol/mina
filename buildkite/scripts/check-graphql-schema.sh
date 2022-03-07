#!/bin/bash
set -eo pipefail

export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
export GO=/usr/lib/go/bin/go

eval $(opam env)
make update-graphql
git diff --exit-code -- graphql_schema.json

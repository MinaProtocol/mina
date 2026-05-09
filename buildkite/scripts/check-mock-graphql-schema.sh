#!/bin/bash
# Verify the mock daemon GraphQL schema is up-to-date and a structural subset
# of the real daemon schema.
#
# Two checks:
#   1. Regenerate mock_schema.json via dune; fail if it differs from the
#      committed copy (committers forgot to run `make update-mock-graphql`).
#   2. Verify mock_schema.json is a STRUCTURAL SUBSET of graphql_schema.json
#      (every type/field in mock exists in real with matching shape; the real
#      schema is allowed to have more).
#
# See src/test/daemon/graphql_mock/README.md for the drift-detection design.

set -eo pipefail

export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
export GO=/usr/lib/go/bin/go

eval "$(opam env)"

# (1) Regeneration check: committed mock_schema.json must equal what dune produces.
make update-mock-graphql
git diff --exit-code -- mock_schema.json

# (2) Subset check: mock must not declare types/fields the real schema lacks.
#     Run from repo root so the relative paths to both schemas resolve.
python3 scripts/check-mock-schema-subset.py mock_schema.json graphql_schema.json

#!/bin/bash
# Verify the mock daemon GraphQL schema is a structural subset of the real
# daemon schema.
#
# Under option C (the shared [Mina_graphql.Types.Make_daemon_status] functor),
# schema drift in the migrated subtrees is impossible at compile time --
# real and mock literally execute the same OCaml schema definition. For the
# remaining parallel types still defined in [Mock_types], this subset check
# catches structural divergence (every type/field/arg the mock declares must
# exist in [graphql_schema.json] with matching shape; the real schema is
# allowed to have more).
#
# See src/test/daemon/graphql_mock/README.md for the design.

set -eo pipefail

export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
export GO=/usr/lib/go/bin/go

eval "$(opam env)"

# Build the introspection JSON into _build (not promoted to source tree).
make build-mock-graphql

# Upload the produced introspection JSON as a build artifact so a maintainer
# can inspect what the mock is currently advertising.
if command -v buildkite-agent >/dev/null 2>&1; then
  buildkite-agent artifact upload _build/default/mock_schema.json || true
fi

# Subset check: mock must not declare types/fields the real schema lacks.
# Run from repo root so the relative paths to both schemas resolve.
python3 scripts/check-mock-schema-subset.py \
  _build/default/mock_schema.json \
  graphql_schema.json

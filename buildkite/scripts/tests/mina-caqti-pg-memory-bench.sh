#!/bin/bash

# Mina_caqti postgres memory-usage benchmark (CI runner)
#
# Provisions a local PostgreSQL, builds and runs the pg_memory micro-benchmark
# (src/lib/mina_caqti/test/pg_memory), and writes an InfluxDB line-protocol perf
# file to /workdir so that buildkite/scripts/bench/send.sh uploads it.
#
# USAGE:
#   ./mina-caqti-pg-memory-bench.sh <user> <password> <db> [iterations]
#
# Must be run from the repository root (where dune-project exists), inside the
# mina-toolchain image (opam env + postgres available), same as
# archive-node-unit-tests.sh.

set -euo pipefail

if [[ ! -f dune-project ]]; then
    echo "Error: run from the repository root (where 'dune-project' exists)."
    exit 1
fi

user="${1:-}"
password="${2:-}"
db="${3:-}"
iterations="${4:-4000}"
perf_file="${PERF_OUTPUT_FILE:-/workdir/mina_caqti_pg_memory.perf}"

if [[ -z "$user" || -z "$password" || -z "$db" ]]; then
    echo "Usage: $0 <user> <password> <db> [iterations]"
    exit 1
fi

eval "$(opam config env)"

echo "Provisioning PostgreSQL for the micro-benchmark..."
# Exports MINA_TEST_POSTGRES / PGPORT (also loads the archive schema, which the
# benchmark does not need but is harmless).
source ./buildkite/scripts/setup-database-for-archive-node.sh "${user}" "${password}" "${db}"

echo "Building the micro-benchmark..."
dune build src/lib/mina_caqti/test/pg_memory/main.exe

echo "Running the micro-benchmark (${iterations} iterations/scenario)..."
./_build/default/src/lib/mina_caqti/test/pg_memory/main.exe \
    --uri "${MINA_TEST_POSTGRES}" \
    --iterations "${iterations}" \
    --variant "${MINA_BENCH_VARIANT:-ci}" \
    --git-branch "${BUILDKITE_BRANCH:-unknown}" \
    --git-commit "${BUILDKITE_COMMIT:-unknown}" \
    --influxdb-file "${perf_file}"

echo "Wrote perf metrics to ${perf_file}:"
cat "${perf_file}"

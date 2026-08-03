#!/bin/bash

# Mina_caqti postgres memory-usage benchmark (CI runner)
#
# Builds and runs the pg_memory micro-benchmark (src/lib/mina_caqti/test/pg_memory)
# and writes an InfluxDB line-protocol perf file to /workdir so that
# buildkite/scripts/bench/send.sh uploads it.
#
# The PostgreSQL instance is provided by RunWithPostgres (see the Buildkite job),
# which exports PG_CONN; the benchmark creates its own scratch tables, so no
# schema is loaded here.
#
# USAGE:
#   ./mina-caqti-pg-memory-bench.sh [iterations]
#
# Must be run from the repository root (where dune-project exists), inside the
# mina-toolchain image with $PG_CONN set.

set -euo pipefail

if [[ ! -f dune-project ]]; then
    echo "Error: run from the repository root (where 'dune-project' exists)."
    exit 1
fi

iterations="${1:-4000}"
perf_file="${PERF_OUTPUT_FILE:-/workdir/mina_caqti_pg_memory.perf}"
pg_uri="${PG_CONN:-${POSTGRES_URI:-}}"
: "${pg_uri:?PG_CONN or POSTGRES_URI must be set (provided by RunWithPostgres)}"

# mina_caqti pulls in mina_base, whose kimchi bindings need the Rust toolchain.
export PATH="/home/opam/.cargo/bin:$PATH"

eval "$(opam config env)"

echo "Building the micro-benchmark..."
dune build src/lib/mina_caqti/test/pg_memory/main.exe

echo "Running the micro-benchmark (${iterations} iterations/scenario)..."
./_build/default/src/lib/mina_caqti/test/pg_memory/main.exe \
    --uri "${pg_uri}" \
    --iterations "${iterations}" \
    --variant "${MINA_BENCH_VARIANT:-ci}" \
    --git-branch "${BUILDKITE_BRANCH:-unknown}" \
    --git-commit "${BUILDKITE_COMMIT:-unknown}" \
    --influxdb-file "${perf_file}"

echo "Wrote perf metrics to ${perf_file}:"
cat "${perf_file}"

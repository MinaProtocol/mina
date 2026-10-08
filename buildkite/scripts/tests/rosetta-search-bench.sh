#!/bin/bash

# Rosetta /search/transactions latency benchmark (CI runner)
#
# RunWithPostgres has already loaded src/app/rosetta/search_bench/init.sql
# into $PG_CONN. This builds and runs the bench and writes an InfluxDB
# line-protocol perf file to /workdir for buildkite/scripts/bench/send.sh.
#
# USAGE:
#   ./rosetta-search-bench.sh [runs]
#
# Must be run from the repository root, inside the mina-toolchain image.

set -euo pipefail

if [[ ! -f dune-project ]]; then
    echo "Error: run from the repository root (where 'dune-project' exists)."
    exit 1
fi

runs="${1:-5}"
perf_file="${PERF_OUTPUT_FILE:-/workdir/rosetta_search_bench.perf}"
: "${PG_CONN:?PG_CONN must be set (provided by RunWithPostgres)}"

# rosetta links mina_base, whose kimchi bindings need the Rust toolchain.
export PATH="/home/opam/.cargo/bin:$PATH"

eval "$(opam config env)"
export MINA_PROFILE=dev

echo "Building the benchmark..."
dune build src/app/rosetta/search_bench/rosetta_search_bench.exe

echo "Running the benchmark (${runs} runs per shape)..."
./_build/default/src/app/rosetta/search_bench/rosetta_search_bench.exe \
    --uri "${PG_CONN}" \
    --runs "${runs}" \
    --variant "${MINA_BENCH_VARIANT:-ci}" \
    --git-branch "${BUILDKITE_BRANCH:-unknown}" \
    --git-commit "${BUILDKITE_COMMIT:-unknown}" \
    --influxdb-file "${perf_file}"

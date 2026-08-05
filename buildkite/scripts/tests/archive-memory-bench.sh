#!/bin/bash

# Archive-node end-to-end memory benchmark (CI runner)
#
# Replays a static, zkApp-heavy corpus of precomputed blocks
# (src/test/archive/sample_zkapp_heavy) through the REAL archive insert path
# (archive_blocks --precomputed -> Processor.add_block_aux_precomputed -> the
# Mina_caqti helpers) directly into PostgreSQL, and samples the resident memory
# of both sides while it runs:
#   * the archive_blocks OCaml process (Caqti prepared-statement cache growth)
#   * the serving PostgreSQL backend (server-side plan cache / CacheMemoryContext)
#
# A leaking build grows the backend's RSS roughly with the number of blocks and
# zkApp events/actions ingested; a fixed build keeps it flat. The result is
# written as InfluxDB line protocol to /workdir so buildkite/scripts/bench/send.sh
# uploads it, using the same measurement/tag convention as the mina_caqti
# micro-benchmark.
#
# The PostgreSQL instance — with the archive schema already loaded — is provided
# by RunWithPostgres, which exports POSTGRES_URI / POSTGRES_DB. Run from the
# repository root inside the mina-toolchain image.

set -euo pipefail

if [[ ! -f dune-project ]]; then
    echo "Error: run from the repository root (where 'dune-project' exists)."
    exit 1
fi

perf_file="${PERF_OUTPUT_FILE:-/workdir/archive_memory_bench.perf}"
corpus_archive="src/test/archive/sample_zkapp_heavy/precomputed_blocks.tar.xz"
sample_sec="${ARCHIVE_BENCH_SAMPLE_SEC:-1}"
measurement="${ARCHIVE_BENCH_MEASUREMENT:-archive_memory_bench}"
: "${POSTGRES_URI:?POSTGRES_URI must be set}"
db="${POSTGRES_DB:?POSTGRES_DB must be set}"

eval "$(opam config env)"

echo "Building archive_blocks..."
dune build src/app/archive_blocks/archive_blocks.exe
AB=./_build/default/src/app/archive_blocks/archive_blocks.exe

echo "Unpacking the static zkApp-heavy corpus..."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tar xJf "$corpus_archive" -C "$work"
mapfile -t files < <(find "$work" -name '*.json' | sort)
echo "  ${#files[@]} precomputed blocks"

PSQL() { psql -tAq "$POSTGRES_URI" -c "$1" 2>/dev/null; }
rss_kib() {
    local key value
    [[ -r "/proc/$1/status" ]] || { echo 0; return; }
    while read -r key value _; do
        if [[ "$key" == "VmRSS:" ]]; then echo "$value"; return; fi
    done < "/proc/$1/status"
    echo 0
}
pg_pids() { PSQL "select pid from pg_stat_activity where datname='$db' and backend_type='client backend' and pid<>pg_backend_pid()"; }
pg_rss_total() { local s=0 p r; for p in $(pg_pids); do r=$(rss_kib "$p"); s=$((s + ${r:-0})); done; echo "$s"; }

succ="$work/successful"; fail="$work/failed"; : > "$succ"; : > "$fail"
csv="$work/curve.csv"; echo "elapsed_s,blocks_done,ab_rss_kib,pg_rss_kib" > "$csv"

echo "Feeding blocks and sampling memory..."
"$AB" --archive-uri "$POSTGRES_URI" --precomputed \
      --successful-files "$succ" --failed-files "$fail" \
      --log-successful false "${files[@]}" > "$work/ablog" 2>&1 &
abpid=$!

t0=$(date +%s)
while kill -0 "$abpid" 2>/dev/null; do
    el=$(( $(date +%s) - t0 ))
    done=$(wc -l < "$succ" 2>/dev/null | tr -d ' ')
    echo "${el},${done:-0},$(rss_kib "$abpid"),$(pg_rss_total)" >> "$csv"
    sleep "$sample_sec"
done
wait "$abpid" || { echo "archive_blocks failed:"; cat "$work/ablog"; exit 1; }
ingest_seconds=$(( $(date +%s) - t0 ))

blocks_ok=$(wc -l < "$succ" | tr -d ' '); blocks_failed=$(wc -l < "$fail" | tr -d ' ')
# throughput (blocks per second) to three decimals, in integer arithmetic;
# guard against a zero-second run
if (( ingest_seconds > 0 )); then
    milli_per_sec=$(( (blocks_ok * 1000 + ingest_seconds / 2) / ingest_seconds ))
    blocks_per_sec=$(printf '%d.%03d' $(( milli_per_sec / 1000 )) $(( milli_per_sec % 1000 )))
else
    blocks_per_sec="0.000"
fi

# Robust metrics: drop the pre-init startup samples (ab_rss < 50MB), then take
# steady-state archive RSS growth, the PG-backend RSS peak, and the mean backend
# RSS over the final third of the run (the sustained level once the zkApp-heavy
# tail is being ingested). Peak and tail-mean both track the leak monotonically.
ab_first=0 ab_last=0 ab_samples=0 pg_peak=0
pg_series=()
while IFS=, read -r _elapsed _blocks_done ab_rss pg_rss; do
    if (( ab_rss > 50000 )); then
        if (( ab_samples == 0 )); then ab_first=$ab_rss; fi
        ab_samples=$(( ab_samples + 1 ))
        ab_last=$ab_rss
        if (( pg_rss > 0 )); then
            pg_series+=( "$pg_rss" )
            if (( pg_rss > pg_peak )); then pg_peak=$pg_rss; fi
        fi
    fi
done < <(tail -n +2 "$csv")

ab_growth=$(( ab_last - ab_first ))
pg_samples=${#pg_series[@]}
pg_tail_avg=0
if (( pg_samples > 0 )); then
    tail_sum=0
    tail_count=0
    for (( i = 2 * pg_samples / 3; i < pg_samples; i++ )); do
        tail_sum=$(( tail_sum + pg_series[i] ))
        tail_count=$(( tail_count + 1 ))
    done
    if (( tail_count > 0 )); then
        pg_tail_avg=$(( tail_sum / tail_count ))
    else
        pg_tail_avg=$pg_peak
    fi
fi

ts_ns=$(date +%s%N)
sanitize() { printf '%s' "$1" | tr ' ,=' '___'; }
variant=$(sanitize "${MINA_BENCH_VARIANT:-ci}")
branch=$(sanitize "${BUILDKITE_BRANCH:-${GIT_BRANCH:-unknown}}")
commit=$(sanitize "${BUILDKITE_COMMIT:-${GIT_COMMIT:-unknown}}")

mkdir -p "$(dirname "$perf_file")"
printf '%s,variant=%s,git_branch=%s,git_commit=%s blocks_ok=%di,blocks_failed=%di,archive_rss_growth_kib=%di,pg_backend_rss_peak_kib=%di,pg_backend_rss_tail_avg_kib=%di,ingest_seconds=%di,blocks_per_sec=%s %s\n' \
    "$(sanitize "$measurement")" "$variant" "$branch" "$commit" \
    "${blocks_ok:-0}" "${blocks_failed:-0}" "${ab_growth:-0}" "${pg_peak:-0}" "${pg_tail_avg:-0}" \
    "${ingest_seconds:-0}" "${blocks_per_sec:-0}" \
    "$ts_ns" > "$perf_file"

echo "=== growth curve ==="
cat "$csv"
echo "=== summary ==="
echo "  blocks_ok=$blocks_ok blocks_failed=$blocks_failed"
echo "  archive_blocks RSS growth   : ${ab_growth} KiB"
echo "  pg backend RSS peak         : ${pg_peak} KiB ($(( ${pg_peak:-0} / 1024 )) MiB)"
echo "  pg backend RSS tail average : ${pg_tail_avg} KiB ($(( ${pg_tail_avg:-0} / 1024 )) MiB)"
echo "  ingest time                 : ${ingest_seconds} s"
echo "  throughput                  : ${blocks_per_sec} blocks/s"
echo "=== influxdb line protocol -> ${perf_file} ==="
cat "$perf_file"

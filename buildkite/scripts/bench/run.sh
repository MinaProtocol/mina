#!/bin/bash

set -eox pipefail

YELLOW_THRESHOLD="0.1"
RED_THRESHOLD="0.3"
BRANCH="${BRANCH:-BUILDKITE_BRANCH}"

while [[ "$#" -gt 0 ]]; do case $1 in
  heap-usage) BENCHMARK="heap-usage"; ;;
  mina-base) BENCHMARK="mina-base"; ;;
  archive) BENCHMARK="archive"; ;;
  ledger-export) BENCHMARK="ledger-export"; ;;
  ledger-apply) BENCHMARK="ledger-apply"; ;;
  snark)
    BENCHMARK="snark"
    K=1
    MAX_NUM_UPDATES=4
    MIN_NUM_UPDATES=2
  ;;
  zkapp) BENCHMARK="zkapp"; ;;
  --yellow-threshold) YELLOW_THRESHOLD="$2"; shift;;
  --red-threshold) RED_THRESHOLD="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

# Each bench feeds its data to mina-bench-upload (the Rust parser + InfluxDB
# uploader in the toolchain image), mapped to its parser --format. Stdout
# benches run a binary (run_ported_bench); parse-only benches read a
# pre-generated file named in BENCH_UPLOAD_INPUT.
declare -A BENCH_UPLOAD_FORMAT=(
  ["heap-usage"]="heap"
  ["zkapp"]="zkapp"
  ["mina-base"]="mina-base"
  ["ledger-export"]="ledger-export"
  ["snark"]="snark"
  ["archive"]="archive"
  ["ledger-apply"]="ledger-apply"
)

# Parse-only benches: the input file (produced by the job's preCommands -- the
# cached archive.perf, or input.json from ledger_test_apply.sh) that
# mina-bench-upload reads via --input, instead of a binary's stdout.
declare -A BENCH_UPLOAD_INPUT=(
  ["archive"]="archive.perf"
  ["ledger-apply"]="input.json"
)
UPLOAD_FORMAT="${BENCH_UPLOAD_FORMAT[$BENCHMARK]:-}"
UPLOAD_INPUT="${BENCH_UPLOAD_INPUT[$BENCHMARK]:-}"

if [[ -z "$UPLOAD_FORMAT" ]]; then
  echo "run.sh: no mina-bench-upload --format for benchmark '${BENCHMARK:-}'" >&2
  exit 1
fi

# Emit the bench binary's stdout for $BENCHMARK; the caller pipes it into
# mina-bench-upload.
run_ported_bench () {
  case "$BENCHMARK" in
    heap-usage)
      mina-heap-usage ;;
    zkapp)
      mina-zkapp-limits ;;
    mina-base)
      BENCHMARKS_RUNNER=TRUE X_LIBRARY_INLINING=true \
        mina-benchmarks time cycles alloc -clear-columns -all-values \
          -width 1000 -run-without-cross-library-inlining -suppress-warnings ;;
    ledger-export)
      RUNTIME_CONFIG=./genesis_ledgers/devnet.json \
        mina-ledger-export-benchmark time cycles alloc -clear-columns \
          -all-values -width 1000 ;;
    snark)
      mina transaction-snark-profiler --zkapps \
        --k "$K" --max-num-updates "$MAX_NUM_UPDATES" \
        --min-num-updates "$MIN_NUM_UPDATES" ;;
    *)
      echo "run_ported_bench: no command defined for $BENCHMARK" >&2
      exit 1 ;;
  esac
}

# The stdout micro-benchmarks each invoke a single self-contained test-suite
# executable; use the freshly-built bare binary from the apps cache when
# available (no .deb required), else fall back to the .deb. The parse-only
# benches (archive, ledger-apply) run no binary here -- their input file is
# produced by the job's preCommands -- so they need neither.
BARE_NONE=false
case "$BENCHMARK" in
  mina-base)     BARE_EXE=benchmarks.exe;              BARE_AS=mina-benchmarks ;;
  heap-usage)    BARE_EXE=heap_usage.exe;              BARE_AS=mina-heap-usage ;;
  zkapp)         BARE_EXE=zkapp_limits.exe;            BARE_AS=mina-zkapp-limits ;;
  ledger-export) BARE_EXE=ledger_export_benchmark.exe; BARE_AS=mina-ledger-export-benchmark ;;
  snark)         BARE_EXE=mina.exe;                    BARE_AS=mina ;;
  archive)       BARE_NONE=true ;;
  ledger-apply)  BARE_NONE=true ;;
  *)             BARE_EXE="" ;;
esac

# The daemon binary resolves its node profile from MINA_PROFILE, defaulting to
# "dev" (ledger_depth 10) when unset. Benches run against devnet-sized data, so
# pin the profile to devnet (ledger_depth 35) -- the .deb path gets this from
# /etc/coda/build_config/PROFILE, the bare-cache binary needs it set explicitly.
export MINA_PROFILE=devnet

INSTALLED_BARE=false
if [[ "$BARE_NONE" == true ]]; then
  git config --global --add safe.directory /workdir
  source buildkite/scripts/export-git-env-vars.sh
  echo "$BENCHMARK bench is parse-only here; skipping binary and .deb install"
  INSTALLED_BARE=true
elif [[ -n "$BARE_EXE" ]]; then
  git config --global --add safe.directory /workdir
  source buildkite/scripts/export-git-env-vars.sh

  if ./buildkite/scripts/apps/restore_app.sh "$BARE_EXE" "$BARE_AS"; then
    echo "Using bare $BARE_AS from apps cache (no .deb needed)"
    INSTALLED_BARE=true
  fi
fi

if [[ "$INSTALLED_BARE" == false ]]; then
  source buildkite/scripts/bench/install.sh
fi

# Feed the bench data to mina-bench-upload: it parses the output, uploads the
# records to InfluxDB (creds from the INFLUX_* env set by Benchmarks.toEnvList)
# and runs the historical-mean regression check against the union of the
# mainline branches (a wider, more stable baseline than a single branch, which
# matters for noisy timing benches). A red regression exits non-zero.
compare_flags=()
for b in develop compatible master; do compare_flags+=(--compare-branch "$b"); done
if [[ -n "$UPLOAD_INPUT" ]]; then
  # Parse-only bench: read the file the job's preCommands generated.
  mina-bench-upload \
    --format "$UPLOAD_FORMAT" \
    --input "$UPLOAD_INPUT" \
    --branch "$BRANCH" \
    --upload \
    --check-regression \
    --yellow "$YELLOW_THRESHOLD" \
    --red "$RED_THRESHOLD" \
    "${compare_flags[@]}"
else
  run_ported_bench | mina-bench-upload \
    --format "$UPLOAD_FORMAT" \
    --branch "$BRANCH" \
    --upload \
    --check-regression \
    --yellow "$YELLOW_THRESHOLD" \
    --red "$RED_THRESHOLD" \
    "${compare_flags[@]}"
fi

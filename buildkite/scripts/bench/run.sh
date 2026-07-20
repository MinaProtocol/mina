#!/bin/bash

set -eox pipefail

YELLOW_THRESHOLD="0.1"
RED_THRESHOLD="0.3"
EXTRA_ARGS="${EXTRA_ARGS:-}"
BRANCH="${BRANCH:-BUILDKITE_BRANCH}"

MAINLINE_BRANCHES="-m develop -m compatible -m master -m dkijania/bench_for_ledger_test"
while [[ "$#" -gt 0 ]]; do case $1 in
  heap-usage) BENCHMARK="heap-usage"; ;;
  mina-base) BENCHMARK="mina-base"; ;;
  archive)
    BENCHMARK="archive";
    EXTRA_ARGS="--no-run ${EXTRA_ARGS}"

  ;;
  ledger-export)
    BENCHMARK="ledger-export"
    EXTRA_ARGS="--genesis-ledger-path ./genesis_ledgers/devnet.json"
  ;;
  ledger-apply)
    BENCHMARK="ledger-apply"
  ;;
  snark)
    BENCHMARK="snark";
    K=1
    MAX_NUM_UPDATES=4
    MIN_NUM_UPDATES=2
    EXTRA_ARGS="--k ${K} --max-num-updates ${MAX_NUM_UPDATES} --min-num-updates ${MIN_NUM_UPDATES}"
  ;;
  zkapp) BENCHMARK="zkapp"; ;;
  --yellow-threshold) YELLOW_THRESHOLD="$2"; shift;;
  --red-threshold) RED_THRESHOLD="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

# The mina-base, heap-usage and zkapp micro-benchmarks each invoke a single
# self-contained test-suite executable with no genesis ledger, /etc/mina config
# or network -- so the freshly-built bare binary from the apps cache is enough,
# no .deb required. Map each to its cached exe and the name the python harness
# expects on PATH (mirroring what the deb installs):
#   - mina-base/heap-usage/zkapp/ledger-export: a self-contained micro-bench exe.
#     ledger-export reads only ./genesis_ledgers/devnet.json (in-repo, passed via
#     --genesis-ledger-path), not a deb payload.
#   - snark: `mina transaction-snark-profiler`, a self-contained mina subcommand
#     (it generates its own transactions), restored as plain `mina`.
#   - archive: runs with --no-run; it only parses a pre-generated JSON into CSV
#     and executes no binary, so neither a .deb nor a cached exe is needed.
#   - ledger-apply: its pre-command generates the benchmark JSON; this step only
#     parses and compares that file, so it does not need a binary or .deb.
# Any cache miss falls back to the .deb.
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
  pip3 install -r scripts/benchmarks/requirements.txt
  INSTALLED_BARE=true
elif [[ -n "$BARE_EXE" ]]; then
  git config --global --add safe.directory /workdir
  source buildkite/scripts/export-git-env-vars.sh

  if ./buildkite/scripts/apps/restore_app.sh devnet "$BARE_EXE" "$BARE_AS"; then
    echo "Using bare $BARE_AS from apps cache (no .deb needed)"
    pip3 install -r scripts/benchmarks/requirements.txt
    INSTALLED_BARE=true
  fi
fi

if [[ "$INSTALLED_BARE" == false ]]; then
  source buildkite/scripts/bench/install.sh
fi

python3 ./scripts/benchmarks test --benchmark ${BENCHMARK}  --branch ${BRANCH} --tmpfile ${BENCHMARK}.csv --yellow-threshold $YELLOW_THRESHOLD --red-threshold $RED_THRESHOLD $MAINLINE_BRANCHES $EXTRA_ARGS

#!/usr/bin/env bash

# Spins up a single-daemon Mina network (seed + whale block producer + snark
# coordinator in one process, holding >99.99% of stake) tuned so that, with
# enough transactions, every block emits a freshly snarked ledger.
#
# Two presets over scripts/mina-local-network/mina-local-network.sh, both with
# full proofs, transaction capacity 2^2 and work_delay 0 (4 scan-state trees,
# ledger proof emitted 3 blocks after a transaction is included):
#
#   default : 3 snark workers, 135s slots  (txn -> snarked ledger ~405s)
#             throughput-bound; zkApp transactions must stay <= 8 segments
#   --fast  : 7 snark workers,  75s slots  (txn -> snarked ledger ~225s)
#             latency-bound; zkApp transactions may go up to 10 segments
#
# Sizing assumes ~10s per proof task (segment / merge / simple base) and a
# block shape of: coinbase + fee transfer + 2 zkApp commands. The block
# producer's blockchain proof must also fit within a slot on this machine.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)"

FAST=false
MINA_EXE_ARG=""
EXTRA_ARGS=()

help() {
  cat <<EOF
Usage: $(basename "$0") [--fast] [--mina-exe <path>] [-- <extra mina-local-network.sh args>]

--fast            | Use the fast preset: 7 snark workers, 75s slots (~225s txn -> snarked ledger).
                  | Default preset: 3 snark workers, 135s slots (~405s txn -> snarked ledger).
--mina-exe <path> | Path to a mina executable to run the network with.
                  | When not provided, mina is built with nix (flake package
                  | '#devnet', as in scripts/hardfork/build-and-test.sh) and the
                  | resulting binary is used.
-h                | Show this help.

Any other argument is forwarded verbatim to mina-local-network.sh *after* the
preset's arguments, so it can override them (e.g. '-c inherit' to reuse a
previously generated config and proving keys, or '-st 150000' to slow down).

NOTE: the first run with a given preset generates proving keys for its
constraint constants (slow, one-time). The presets share circuits, so
switching between them only requires '-c reset' for the new slot time.
EOF
  exit
}

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
  --fast)
    FAST=true
    ;;
  --mina-exe)
    if [[ "$#" -lt 2 ]]; then
      echo "Error: --mina-exe requires an argument." >&2
      exit 1
    fi
    MINA_EXE_ARG="${2}"
    shift
    ;;
  -h | --help)
    help
    ;;
  --)
    shift
    EXTRA_ARGS+=("$@")
    break
    ;;
  *)
    EXTRA_ARGS+=("${1}")
    ;;
  esac
  shift
done

if ${FAST}; then
  PRESET="fast (#2: 7 workers, 75s slots, zkApps up to 10 segments)"
  SNARK_WORKERS=7
  SLOT_TIME_MS=75000
  TRANSACTION_INTERVAL=15
else
  PRESET="default (#5: 3 workers, 135s slots, zkApps up to 8 segments)"
  SNARK_WORKERS=3
  SLOT_TIME_MS=135000
  TRANSACTION_INTERVAL=25
fi

# Resolve the mina executable: use the one provided via --mina-exe, otherwise
# build it with nix the same way scripts/hardfork/build-and-test.sh does.
if [[ -n "${MINA_EXE_ARG}" ]]; then
  if [[ ! -x "${MINA_EXE_ARG}" ]]; then
    echo "Error: --mina-exe '${MINA_EXE_ARG}' does not exist or is not executable." >&2
    exit 1
  fi
  MINA_EXE="$(realpath "${MINA_EXE_ARG}")"
else
  echo "No --mina-exe provided; building mina with nix (this may take a while)..."
  NIX_OPTS=( --accept-flake-config --experimental-features 'nix-command flakes' )
  git -C "${REPO_ROOT}" submodule update --init --recursive --depth 1
  nix "${NIX_OPTS[@]}" build "${REPO_ROOT}?submodules=1#devnet" \
    --out-link "${REPO_ROOT}/single-node-devnet"
  MINA_EXE="${REPO_ROOT}/single-node-devnet/bin/mina"
fi
export MINA_EXE
echo "Using mina executable: ${MINA_EXE}"

echo "Starting single-node network with preset: ${PRESET}"

# mina-local-network.sh refers to its helper scripts relative to the repo root.
cd "${REPO_ROOT}"

exec "${SCRIPT_DIR}/mina-local-network.sh" \
  -c reset \
  -u delay_sec:120 \
  -pl full \
  -tc 2 \
  -wd 0 \
  -st "${SLOT_TIME_MS}" \
  -swc "${SNARK_WORKERS}" \
  -sf 0.001 \
  -vt -ti "${TRANSACTION_INTERVAL}" \
  -w 1 -f 0 -n 0 \
  --seed-is-whale \
  --seed-is-coordinator \
  "${EXTRA_ARGS[@]}"

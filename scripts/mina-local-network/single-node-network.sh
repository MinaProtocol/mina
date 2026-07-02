#!/usr/bin/env bash

# Spins up a single-daemon Mina network (seed + whale block producer + snark
# coordinator in one process, holding >99.99% of stake) tuned so that, with
# enough transactions, every block emits a freshly snarked ledger.
#
# Three presets over scripts/mina-local-network/mina-local-network.sh, all with
# transaction capacity 2^2 (4 scan-state trees). The proof-based presets use
# work_delay 0 (a ledger proof emitted ~3 blocks after a transaction is
# included); --no-proofs uses work_delay 1 to avoid a scan-state stall under
# sustained load (see the WORK_DELAY note below):
#
#   default     : full proofs, 3 snark workers, 131.4s slots (txn -> snarked
#                 ledger ~395s); throughput-bound, zkApp txns must stay <= 8 segs
#   --fast      : full proofs, 7 snark workers, 75s slots (txn -> snarked ledger
#                 ~225s); latency-bound, zkApp txns may go up to 10 segments
#   --no-proofs : proof_level=none, 1 snark worker, 2s slots. No snarked-ledger
#                 proving on the node, so throughput is not proving-bound and the
#                 turnaround is fast -- meant for quick iteration on local boxes.
#
# NOTE on slot times: consensus requires floor(365days_ms / slot_ms) to be
# divisible by 12 (checkpoint window sizing, src/lib/consensus/constants.ml),
# i.e. pick slot times dividing 2628000000 ms. 2000, 75000 and 131400 all
# qualify; a round 135000 does not and crashes the daemon at startup. With
# --epoch-min the derived slot time is snapped to a valid divisor automatically.
#
# Sizing assumes ~10s per proof task (segment / merge / simple base) and a
# block shape of: coinbase + fee transfer + 2 zkApp commands. The block
# producer's blockchain proof must also fit within a slot on this machine.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)"

FAST=false
NO_PROOFS=false
EPOCH_MIN=""
PRINT_SLOT_MS=false
MINA_EXE_ARG=""
VALUE_TRANSFERS=true
# This network is meant to run for a long time, so by default disable the
# daemon's ~weekly self-restart (mina default --stop-time 168h) by setting it to
# 5 years. Override with --stop-time-hours (e.g. 168 to restore the default).
STOP_TIME_HOURS=43800
# Archive node. When --archive is passed, an archive node is spawned alongside
# the network (via mina-local-network.sh -ap) and the seed daemon streams its
# blocks to it. The PostgreSQL connection is taken from the PG_* environment
# variables read by mina-local-network.sh (single-node-load.sh brings up an
# ephemeral cluster and exports them); run PostgreSQL yourself when invoking this
# script directly with --archive.
ARCHIVE=false
ARCHIVE_PORT=3086
ARCHIVE_EXE_ARG=""
EXTRA_ARGS=()

help() {
  cat <<EOF
Usage: $(basename "$0") [--fast | --no-proofs] [--epoch-min <#>] [--mina-exe <path>] [-- <extra mina-local-network.sh args>]

--fast            | Use the fast preset: 7 snark workers, 75s slots (~225s txn -> snarked ledger).
                  | Default preset: 3 snark workers, 131.4s slots (~395s txn -> snarked ledger).
--no-proofs       | Fast-iteration preset: proof_level=none, a single snark
                  | worker (no real work to do), and a minimal 2s slot. No
                  | snarked-ledger proving on the node. Mutually exclusive with --fast.
--epoch-min <#>   | Target epoch length in minutes. There are always 48 slots
                  | per epoch, so the slot time is derived as epoch/48 and then
                  | snapped to the nearest value dividing 2_628_000_000 ms (a
                  | consensus checkpoint-window requirement) and floored to the
                  | preset's minimum slot. Without it the preset slot is used.
--stop-time-hours <#> | Uptime (hours) after which the daemon stops itself.
                  | The mina default is 168 (~weekly self-restart); this script
                  | defaults to 43800 (5 years) so the network does not restart
                  | on its own. Pass 168 to restore the upstream behaviour.
--mina-exe <path> | Path to a mina executable to run the network with.
                  | When not provided, mina is built with nix (flake package
                  | '#devnet', as in scripts/hardfork/build-and-test.sh) and the
                  | resulting binary is used.
--archive         | Spawn an archive node and stream the seed daemon's blocks to
                  | it. Requires a reachable PostgreSQL; the connection is read
                  | from the PG_* env vars (PG_HOST/PG_PORT/PG_USER/PG_PW/PG_DB)
                  | that mina-local-network.sh consults. single-node-load.sh
                  | starts an ephemeral cluster and exports these for you.
--archive-port <#>| Archive node server port (default: ${ARCHIVE_PORT}).
--archive-exe <path> | Path to a mina-archive executable. When not provided (and
                  | --archive is set), it is built with nix ('#devnet.archive').
                  | Required if --mina-exe is given, since no nix build happens then.
--no-value-transfers | Do not send periodic value-transfer transactions. Useful
                  | when an external load (e.g. ITN scheduler) keeps the
                  | blocks full instead.
--print-slot-ms   | Resolve the slot time for the given flags, print it (ms) and
                  | exit. Used by single-node-load.sh to compute its send rate.
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
  --no-proofs)
    NO_PROOFS=true
    ;;
  --epoch-min)
    if [[ "$#" -lt 2 ]]; then
      echo "Error: --epoch-min requires an argument." >&2
      exit 1
    fi
    EPOCH_MIN="${2}"
    shift
    ;;
  --stop-time-hours)
    if [[ "$#" -lt 2 ]]; then
      echo "Error: --stop-time-hours requires an argument." >&2
      exit 1
    fi
    STOP_TIME_HOURS="${2}"
    shift
    ;;
  --print-slot-ms)
    PRINT_SLOT_MS=true
    ;;
  --mina-exe)
    if [[ "$#" -lt 2 ]]; then
      echo "Error: --mina-exe requires an argument." >&2
      exit 1
    fi
    MINA_EXE_ARG="${2}"
    shift
    ;;
  --no-value-transfers)
    VALUE_TRANSFERS=false
    ;;
  --archive)
    ARCHIVE=true
    ;;
  --archive-port)
    if [[ "$#" -lt 2 ]]; then
      echo "Error: --archive-port requires an argument." >&2
      exit 1
    fi
    ARCHIVE_PORT="${2}"
    shift
    ;;
  --archive-exe)
    if [[ "$#" -lt 2 ]]; then
      echo "Error: --archive-exe requires an argument." >&2
      exit 1
    fi
    ARCHIVE_EXE_ARG="${2}"
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

if ${FAST} && ${NO_PROOFS}; then
  echo "Error: --fast and --no-proofs are mutually exclusive." >&2
  exit 1
fi

# Each preset fixes the proof level, the snark worker count and a default /
# minimum slot time. --epoch-min may lengthen the slot beyond the floor but
# never shorten it below the per-preset minimum.
PROOF_LEVEL=full
# Scan-state work delay. The proof-based presets keep work_delay=0 (a freshly
# snarked ledger every block once the pipeline is primed); there the proving
# cost sets the pace, so the tight zero-delay schedule is fine and desirable.
# With --no-proofs there is no proving cost and blocks fill from the value-
# transfer generator, and work_delay=0 makes the scan state stall under
# sustained load with "Constraints failed: First pass ledger of the statement on
# the right connects to the second pass ledger of the statement on the left"
# (validate_ledgers_at_merge). work_delay=1 removes the stall; the snarked ledger
# then advances every other block instead of every block, which is fine here.
WORK_DELAY=0
if ${NO_PROOFS}; then
  PRESET="no-proofs (proof_level=none, 1 worker, 2s min slot)"
  PROOF_LEVEL=none
  SNARK_WORKERS=1
  DEFAULT_SLOT_TIME_MS=2000
  SLOT_FLOOR_MS=2000
  TRANSACTION_INTERVAL=4
  WORK_DELAY=1
elif ${FAST}; then
  PRESET="fast (#2: 7 workers, 75s slots, zkApps up to 10 segments)"
  SNARK_WORKERS=7
  DEFAULT_SLOT_TIME_MS=75000
  SLOT_FLOOR_MS=75000
  TRANSACTION_INTERVAL=15
else
  PRESET="default (#5: 3 workers, 131.4s slots, zkApps up to 8 segments)"
  SNARK_WORKERS=3
  DEFAULT_SLOT_TIME_MS=131400
  SLOT_FLOOR_MS=131400
  TRANSACTION_INTERVAL=25
fi

# slots per epoch is fixed at 48 (see reset-genesis-ledger in
# mina-local-network.sh); --epoch-min trades off against the slot time.
if [[ -n "${EPOCH_MIN}" ]]; then
  SLOT_TIME_MS=$(python3 - "${EPOCH_MIN}" "${SLOT_FLOOR_MS}" <<'PYEOF'
import sys
epoch_min = float(sys.argv[1])
floor_ms = int(sys.argv[2])
SLOTS_PER_EPOCH = 48
# slot_ms must divide 2_628_000_000 so floor(365days_ms / slot_ms) stays a
# multiple of 12 (src/lib/consensus/constants.ml checkpoint windows).
N = 2628000000
ideal = epoch_min * 60000.0 / SLOTS_PER_EPOCH
divisors = set()
i = 1
while i * i <= N:
    if N % i == 0:
        divisors.add(i)
        divisors.add(N // i)
    i += 1
candidates = [d for d in divisors if d >= floor_ms]
# closest to the ideal; ties broken towards the larger (slower, safer) slot.
slot = min(candidates, key=lambda d: (abs(d - ideal), -d))
print(int(slot))
PYEOF
)
else
  SLOT_TIME_MS=${DEFAULT_SLOT_TIME_MS}
fi

if ${PRINT_SLOT_MS}; then
  echo "${SLOT_TIME_MS}"
  exit 0
fi

# 48 slots/epoch; epoch minutes = 48*slot_ms/60000, kept to 2 decimals in pure
# bash (48*slot/600 = slot*2/25 centi-minutes) to avoid needing python here.
EPOCH_CENTIMIN=$(( SLOT_TIME_MS * 2 / 25 ))
EPOCH_ACTUAL_MIN="$(( EPOCH_CENTIMIN / 100 )).$(printf '%02d' "$(( EPOCH_CENTIMIN % 100 ))")"

# Resolve the mina executable: use the one provided via --mina-exe, otherwise
# build it with nix the same way scripts/hardfork/build-and-test.sh does.
NIX_OPTS=( --accept-flake-config --experimental-features 'nix-command flakes' )
if [[ -n "${MINA_EXE_ARG}" ]]; then
  if [[ ! -x "${MINA_EXE_ARG}" ]]; then
    echo "Error: --mina-exe '${MINA_EXE_ARG}' does not exist or is not executable." >&2
    exit 1
  fi
  MINA_EXE="$(realpath "${MINA_EXE_ARG}")"
else
  echo "No --mina-exe provided; building mina with nix (this may take a while)..."
  git -C "${REPO_ROOT}" submodule update --init --recursive --depth 1
  nix "${NIX_OPTS[@]}" build "${REPO_ROOT}?submodules=1#devnet" \
    --out-link "${REPO_ROOT}/single-node-devnet"
  MINA_EXE="${REPO_ROOT}/single-node-devnet/bin/mina"
fi
export MINA_EXE
echo "Using mina executable: ${MINA_EXE}"

# Resolve the archive executable when --archive is set. mina-local-network.sh
# defaults ARCHIVE_EXE to a dune-built path that does not exist for nix runs, so
# resolve it here and export it. The '#devnet.archive' flake output provides the
# 'mina-archive' binary (src/app/archive/archive.exe), the same one the docker
# archive image and the hardfork archive test use.
if ${ARCHIVE}; then
  if [[ -n "${ARCHIVE_EXE_ARG}" ]]; then
    if [[ ! -x "${ARCHIVE_EXE_ARG}" ]]; then
      echo "Error: --archive-exe '${ARCHIVE_EXE_ARG}' does not exist or is not executable." >&2
      exit 1
    fi
    ARCHIVE_EXE="$(realpath "${ARCHIVE_EXE_ARG}")"
  elif [[ -n "${MINA_EXE_ARG}" ]]; then
    echo "Error: --archive with --mina-exe also requires --archive-exe <path to mina-archive>." >&2
    exit 1
  else
    echo "No --archive-exe provided; building the archive node with nix (this may take a while)..."
    nix "${NIX_OPTS[@]}" build "${REPO_ROOT}?submodules=1#devnet.archive" \
      --out-link "${REPO_ROOT}/single-node-devnet-archive"
    ARCHIVE_EXE="${REPO_ROOT}/single-node-devnet-archive/bin/mina-archive"
  fi
  export ARCHIVE_EXE
  echo "Using archive executable: ${ARCHIVE_EXE}"
fi

echo "Starting single-node network with preset: ${PRESET}"
echo "Slot time: ${SLOT_TIME_MS}ms (48 slots/epoch -> epoch ~${EPOCH_ACTUAL_MIN} min)"

# mina-local-network.sh generates the genesis ledger (and optionally sends
# GraphQL queries) with python helpers that need the 'click' and 'requests'
# packages. If the ambient python3 lacks them, materialize a suitable
# interpreter with nix-shell and put it in front of PATH.
if ! python3 -c 'import click, requests' 2>/dev/null; then
  if command -v nix-shell >/dev/null; then
    echo "python3 lacks click/requests; getting an interpreter via nix-shell..."
    PYTHON3_WITH_PKGS=$(nix-shell \
      --packages "python3.withPackages (ps: [ ps.click ps.requests ])" \
      --run 'command -v python3')
    PATH="$(dirname "${PYTHON3_WITH_PKGS}"):${PATH}"
    export PATH
  else
    echo "Error: python3 lacks the 'click'/'requests' packages and nix-shell is unavailable." >&2
    echo "Install them, e.g.: pip install -r scripts/mina-local-network/requirements.txt" >&2
    echo "or run inside: nix-shell -p \"python3.withPackages (ps: [ ps.click ps.requests ])\"" >&2
    exit 1
  fi
fi

# mina-local-network.sh refers to its helper scripts relative to the repo root.
cd "${REPO_ROOT}"

VALUE_TRANSFER_ARGS=()
if ${VALUE_TRANSFERS}; then
  VALUE_TRANSFER_ARGS=(-vt -ti "${TRANSACTION_INTERVAL}")
fi

# Enabling the archive is a matter of handing mina-local-network.sh a non-empty
# archive server port (-ap): it then recreates the PostgreSQL schema (reset
# mode), spawns the archive node with --config-file "${ROOT}/daemon.json" (so it
# runs add_genesis_accounts over the genesis ledger) and passes
# -archive-address to the seed daemon so blocks are streamed to it.
ARCHIVE_NET_ARGS=()
if ${ARCHIVE}; then
  ARCHIVE_NET_ARGS=(-ap "${ARCHIVE_PORT}")
fi

exec "${SCRIPT_DIR}/mina-local-network.sh" \
  -c reset \
  -u delay_sec:120 \
  -pl "${PROOF_LEVEL}" \
  -tc 2 \
  -wd "${WORK_DELAY}" \
  -st "${SLOT_TIME_MS}" \
  -swc "${SNARK_WORKERS}" \
  -stopt "${STOP_TIME_HOURS}" \
  -sf 0.001 \
  "${VALUE_TRANSFER_ARGS[@]}" \
  "${ARCHIVE_NET_ARGS[@]}" \
  -w 1 -f 0 -n 0 \
  --seed-is-whale \
  --seed-is-coordinator \
  "${EXTRA_ARGS[@]}"

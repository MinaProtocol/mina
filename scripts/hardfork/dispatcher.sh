#!/usr/bin/env bash
# /usr/lib/mina/bin/mina-dispatch

set -euo pipefail

SOURCE_FILE=${SOURCE_FILE:-"/etc/default/mina-dispatch"}

# shellcheck source=/etc/default/mina-dispatch
source "${SOURCE_FILE}"

MESA_CONFIG_ROOT=${MESA_CONFIG_ROOT:-"${HOME}/.mina-config/auto-fork-${MINA_NETWORK}-${MINA_PROFILE}"}
MESA_CONFIG=${MESA_CONFIG_ROOT}/daemon.json
MESA_LEDGERS_DIR=${MESA_LEDGERS_DIR:-"${MESA_CONFIG_ROOT}/genesis"}

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "mina-dispatch ERROR: source file not found: $SOURCE_FILE. Installation is incomplete or corrupted." >&2
  exit 1
fi

if [[ -z "${MINA_NETWORK:-}" ]]; then
  echo "mina-dispatch ERROR: MINA_NETWORK is not defined. It should have been set in ${SOURCE_FILE}" >&2
  exit 1
fi

if [[ -z "${RUNTIMES_BASE_PATH:-}" ]]; then
  echo "mina-dispatch ERROR: RUNTIMES_BASE_PATH is not defined. It should have been set in ${SOURCE_FILE}" >&2
  exit 1
fi

if [[ -z "${MINA_LIBP2P_ENVVAR_NAME:-}" ]]; then
  echo "mina-dispatch ERROR: MINA_LIBP2P_ENVVAR_NAME is not defined. It should have been set in ${SOURCE_FILE}" >&2
  exit 1
fi

# ---- Fixed layout -----------------------------------------------------------
STATE_FILE=${OVERRIDE_STATE_FILE:-"${MESA_CONFIG_ROOT}/activated"}

if [[ -f "$STATE_FILE" ]]; then
  runtime="mesa"
else
  runtime="berkeley"
fi

cmd="$(basename "$0")"

# Allow direct invocation for debugging:
#   mina-dispatch mina --help
if [[ "$cmd" == "mina-dispatch" ]]; then
  if [[ $# -lt 1 ]]; then
    echo "mina-dispatch ERROR: no command provided" >&2
    exit 1
  fi
  cmd="$1"
  shift
fi

bin="${RUNTIMES_BASE_PATH}/${runtime}/${cmd}"

if [[ ! -x "$bin" ]]; then
  echo "mina-dispatch ERROR: binary not found or not executable: $bin" >&2
  exit 1
fi

# ---- Special case: mina -----------------------------------------------------

if [[ "$cmd" == "mina" ]]; then
  helper="${RUNTIMES_BASE_PATH}/${runtime}/coda-libp2p_helper"
  if [[ ! -x "$helper" ]]; then
    echo "mina-dispatch ERROR: coda-libp2p_helper not found: $helper" >&2
    exit 1
  fi
  export "${MINA_LIBP2P_ENVVAR_NAME}=${helper}"
fi

args=("$@")
if [[ $runtime == "mesa" ]]; then
    # ---- Handle -config-file argument ------------------------------------------
    for i in "${!args[@]}"; do
      if [[ "${args[$i]}" == "-config-file" && $((i + 1)) -lt ${#args[@]} ]]; then
        args[i + 1]="$MESA_CONFIG"
      fi
    done

    # ---- Handle --genesis-ledger-dir argument ------------------------------------------
    found_genesis_ledger_dir=false
    for i in "${!args[@]}"; do
      if [[ "${args[$i]}" == "--genesis-ledger-dir" && $((i + 1)) -lt ${#args[@]} ]]; then
        args[i + 1]="$MESA_LEDGERS_DIR"
        found_genesis_ledger_dir=true
        break
      fi
    done
    
    if [[ "$found_genesis_ledger_dir" == false ]]; then
      args+=("--genesis-ledger-dir" "$MESA_LEDGERS_DIR")
    fi
fi

exec "$bin" "${args[@]}"
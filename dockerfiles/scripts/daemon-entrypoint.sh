#!/bin/bash

set -euo pipefail

# If glob doesn't match anything, return empty string rather than literal pattern
shopt -s nullglob


set -x

INPUT_ARGS="$@"

XDG_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

MINA_STATE_DIR="${XDG_STATE_DIR}/mina"
MINA_RUNTIME_DIR="${RUNTIME_DIR}/mina"

MINA_PROVER_LOG="${MINA_STATE_DIR}/mina-prover.log"
MINA_VERIFIER_LOG="${MINA_STATE_DIR}/mina-verifier.log"
MINA_BEST_TIP_LOG="${MINA_STATE_DIR}/mina-best-tip.log"

MINA_LOCK="${MINA_RUNTIME_DIR}/.mina-lock"


# These arrays can be overwritten or extended in scripts to adjust verbosity
# Example: LOG_FILES+=("${VERBOSE_LOG_FILES[@]}")
declare -a LOG_FILES=('mina.log')
declare -a VERBOSE_LOG_FILES=("${MINA_PROVER_LOG}" "${MINA_VERIFIER_LOG}" "${MINA_BEST_TIP_LOG}")

# Attempt to execute or source custom entrypoint scripts accordingly
for script in /entrypoint.d/*; do
  if [ -x "$script" ]; then
    "$script" $INPUT_ARGS
  else
    source "$script"
  fi
done

# Mina daemon initialization
mkdir -p MINA_STATE_DIR
mkdir -p MINA_RUNTIME_DIR
touch MINA_PROVER_LOG
touch MINA_VERIFIER_LOG
touch MINA_BEST_TIP_LOG

while true; do
  rm -f $MINA_LOCK
  mina $INPUT_ARGS 2>&1 >mina.log &
  mina_pid=$!

  tail -q -f "${LOG_FILES[@]}" &
  tail_pid=$!

  wait "$mina_pid"
  echo "Mina process exited with status code $?"

  kill "$tail_pid"
  if [ ! -f stay_alive ]; then
    sleep 10
    exit 0
  fi
done

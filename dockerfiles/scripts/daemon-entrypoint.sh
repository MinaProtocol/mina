#!/bin/bash

set -euo pipefail

# If glob doesn't match anything, return empty string rather than literal pattern
shopt -s nullglob

INPUT_ARGS="$@"

# These arrays can be overwritten or extended in scripts to adjust verbosity
# Example:
declare -a LOG_FILES=('mina.log')
# stderr is mostly used to print "reading password from environment varible ..."
# prover and verifier logs are also sparse, mostly memory stats and debug info
# mina-best-tip.log is useful for organizing a hard fork and is one way to monitor new blocks as they are added, but not critical
declare -a VERBOSE_LOG_FILES=('mina-stderr.log' '.mina-config/mina-prover.log' '.mina-config/mina-verifier.log' '.mina-config/mina-best-tip.log')

EXTRA_FLAGS=""

# Attempt to execute or source custom entrypoint scripts accordingly
# Example: mount a mina-env file with variable evironment variables to source and pass to the daemon
for script in /entrypoint.d/*; do
  if [ -x "$script" ]; then
    "$script" $INPUT_ARGS
  else
    source "$script"
  fi
done

set +u # allow these variables to be unset
# Support flags from .mina-env on debian
if [[ ${PEER_LIST_URL} ]]; then
  EXTRA_FLAGS+=" --peer-list-url ${PEER_LIST_URL}"
fi
if [[ ${LOG_LEVEL} ]]; then
  EXTRA_FLAGS+=" --log-level ${LOG_LEVEL}"
fi
if [[ ${FILE_LOG_LEVEL} ]]; then
  EXTRA_FLAGS+=" --file-log-level ${FILE_LOG_LEVEL}"
fi

# If VERBOSE=true then also append other log files
if [[ ${VERBOSE} ]]; then
  LOG_FILES+=("${VERBOSE_LOG_FILES[@]}")
  # Print the flags to the daemon for debugging use
  echo "[Debug] Input Args: ${INPUT_ARGS}"
  echo "[Debug] Extra Flags: ${EXTRA_FLAGS}"
fi

set -u

# Mina daemon initialization
mkdir -p .mina-config
# Create all of the log files that we will tail later
touch "${LOG_FILES[@]}"

set +e # Allow wait and kill commands to fail in this loop
while true; do
  rm -f .mina-config/.mina-lock
  mina $INPUT_ARGS $EXTRA_FLAGS 2>mina-stderr.log 1>mina.log &
  mina_pid=$!

  tail -q -f "${LOG_FILES[@]}" &
  tail_pid=$!

  wait "$mina_pid"
  echo "Mina process exited with status code $?"
  sleep 15
  kill "$tail_pid"

  if [ ! -f stay_alive ]; then
    exit 0
  fi
done

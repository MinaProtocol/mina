#!/bin/bash

set -euo pipefail

# If glob doesn't match anything, return empty string rather than literal pattern
shopt -s nullglob
# Match files starting with .
shopt -s dotglob

INPUT_ARGS="$@"

# stderr is mostly used to print "reading password from environment varible ..."
# prover and verifier logs are also sparse, mostly memory stats and debug info
# mina-best-tip.log is useful for organizing a hard fork and is one way to monitor new blocks as they are added, but not critical
declare -a VERBOSE_LOG_FILES=('mina-stderr.log' '.mina-config/mina-prover.log' '.mina-config/mina-verifier.log' '.mina-config/mina-best-tip.log')

# Attempt to execute or source custom entrypoint scripts accordingly
for script in /entrypoint.d/*; do
  if [[ "$( basename "${script}")" == *mina-env ]]; then
    source "${script}"
  elif [[ -f "${script}" ]] && [[ ! -x "${script}" ]]; then
    source "${script}"
  elif [[ -f "${script}" ]]; then
    "${script}" $INPUT_ARGS
  else
    echo "[ERROR] Entrypoint script ${script} is not a regular file, ignoring"
  fi
done

APPENDED_FLAGS=""

set +u # allow these variables to be unset, including EXTRA_FLAGS
# Support flags from .mina-env on debian
if [[ ${PEER_LIST_URL} ]]; then
  APPENDED_FLAGS+=" --peer-list-url ${PEER_LIST_URL}"
fi
if [[ ${PEER_LIST_FILE} ]]; then
  APPENDED_FLAGS+=" --peer-list-file ${PEER_LIST_FILE}"
fi
if [[ ${LOG_LEVEL} ]]; then
  APPENDED_FLAGS+=" --log-level ${LOG_LEVEL}"
fi
if [[ ${FILE_LOG_LEVEL} ]]; then
  APPENDED_FLAGS+=" --file-log-level ${FILE_LOG_LEVEL}"
fi

# If VERBOSE=true then print daemon flags
if [[ ${VERBOSE} ]]; then
  # Print the flags to the daemon for debugging use
  echo "[Debug] Input Arguments: ${INPUT_ARGS}"
  echo "[Debug] Extra Flags: ${EXTRA_FLAGS}"
  echo "[Debug] Dynamically Appended Flags: ${APPENDED_FLAGS}"
fi

# Mina daemon initialization
mkdir -p .mina-config

set +e # Allow remaining commands to fail without exiting early
rm -f .mina-config/.mina-lock

# Export variables that the daemon would read directly
export MINA_PRIVKEY_PASS MINA_LIBP2P_PASS UPTIME_PRIVKEY_PASS

# Run the daemon in the foreground
mina ${INPUT_ARGS} ${EXTRA_FLAGS} ${APPENDED_FLAGS} 2>mina-stderr.log
export MINA_EXIT_CODE="$?"
echo "Mina process exited with status code ${MINA_EXIT_CODE}"

# Don't export variables to exitpoint scripts
export -n MINA_PRIVKEY_PASS MINA_LIBP2P_PASS UPTIME_PRIVKEY_PASS

# Attempt to execute or source custom EXITpoint scripts
# Example: `mina client export-local-logs > ~/.mina-config/log-exports/blah`
#  to export logs every time the daemon shuts down
for script in /exitpoint.d/*; do
  if [[ -f "${script}" ]] && [[ -x "${script}" ]]; then
    "${script}"
  else
    echo "[ERROR] Exitpoint script ${script} is not an executable regular file, ignoring"
  fi
done

# TODO: have a better way to intersperse log files like we used to, without infinite disk use
# For now, tail the last 20 lines of the verbose log files when the node shuts down
if [[ ${VERBOSE} ]]; then
  tail -n 20 "${VERBOSE_LOG_FILES[@]}"
fi

sleep 15 # to allow all mina proccesses to quit, cleanup, and finish logging

#!/bin/bash

# Memory gates for the benchmark jobs.
#
# A benchmark binary exits with MEMORY_GATE_EXIT_STATUS (42) when its memory
# gate fails, and with any other non-zero status for any other failure.
#
#   memory-gate.sh run NAME COMMAND [ARGS...]
#       Runs COMMAND from the repository root. On status 42 it writes
#       NAME.memory-gate-failed in the repository root and exits 0, so that the
#       perf upload after it still runs. Any other status is returned as is.
#
#   memory-gate.sh verdict
#       Run after the upload. Exits 42 if a gate failed in this job, else 0.
#       A job that sets soft_fail on exit status 42 so reports a failed gate
#       without failing; every other failure of the job stays a failure.

set -uo pipefail

MEMORY_GATE_EXIT_STATUS=42

case "${1:-}" in
  run)
    name=${2:?usage: memory-gate.sh run NAME COMMAND [ARGS...]}
    shift 2
    "$@"
    status=$?
    if [[ ${status} -eq ${MEMORY_GATE_EXIT_STATUS} ]]; then
      echo "MEMORY GATE FAILED: ${name}" | tee "${name}.memory-gate-failed"
      exit 0
    fi
    exit "${status}"
    ;;
  verdict)
    shopt -s nullglob
    failed=(*.memory-gate-failed)
    if [[ ${#failed[@]} -gt 0 ]]; then
      cat "${failed[@]}"
      exit "${MEMORY_GATE_EXIT_STATUS}"
    fi
    ;;
  *)
    echo "usage: memory-gate.sh run NAME COMMAND [ARGS...] | verdict" >&2
    exit 2
    ;;
esac

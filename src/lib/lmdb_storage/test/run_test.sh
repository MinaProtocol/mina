#!/bin/bash

# Run an Alcotest executable, and when it fails, say how it ended and show the
# end of what each case printed.
#
# Alcotest sends a case's stdout and stderr to a file under _build/_tests, so a
# process that dies part-way through a case leaves nothing in the dune output,
# and dune does not report the exit status or the fatal signal either.
#
# Usage: run_test.sh <test-executable>

set -u

"./$1"
status=$?

if [[ $status -ne 0 ]]; then
  # Alcotest leaves the line of the interrupted case unterminated.
  echo >&2
  if [[ $status -gt 128 ]]; then
    echo "$1 was killed by signal $((status - 128)) ($(kill -l "$status"))" >&2
  else
    echo "$1 exited with status $status" >&2
  fi
  for output in _build/_tests/latest/*.output; do
    [[ -e "$output" ]] || continue
    echo "--- last lines of $output" >&2
    tail -n 50 "$output" >&2
  done
fi

exit "$status"

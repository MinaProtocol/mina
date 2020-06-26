#!/bin/bash

RESET="\e[0m"
RED="\e[31m"
MAGENTA="\e[35m"
DARK_GREY="\e[90m"

log() { echo -e "$1**** $2 ****$RESET"; }
trace() { log "$MAGENTA" "$1"; }
error() { log "$RED" "$1"; }
heartbeat() { log "$DARK_GREY" 'CI HEARTBEAT'; }

profile="$1"
[ -z "$profile" ] && (error 'BUILD PROFILE ARGUMENT IS REQUIRED' && exit 1)

trace 'BUILDING'
dune build "--profile=$profile" -j8 || (error 'BUILD FAILED' && exit 1)

trace 'RUNNING TESTS'
dune runtest "--profile=$profile" -j8 &
test_pid=$!
trap "kill \"$test_pid\" >/dev/null 2>&1" EXIT

i=0
while ps | grep " $test_pid "; do
  sleep 5
  i="$(( "$i" + 1 ))"
  # print heartbeat once every 2 minutes
  [ "$(( "$i" % 24 ))" = 0 ] && heartbeat
done

wait "$test_pid"
test_status=$?
if [ "$test_status" != 0 ]; then
  error 'TESTS FAILED'
  exit $test_status
else
  trace 'TESTS PASSED'
fi

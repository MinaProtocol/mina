#!/usr/bin/env bash

# Helper script for compiling GO code
# Targets for compilation are to be specified
# as arguments to the script

set -e

if [[ "$GO" == "" ]];then
  GO=go
fi

cmd=build

if [[ "$1" == "--test" ]]; then
  cmd=test
  shift
fi

if [[ $# -lt 1 ]]; then
  echo "No build targets specified"
  exit 2
fi

RESULT_BIN="$PWD/result/bin"
mkdir -p "$RESULT_BIN" || echo "Can't create $RESULT_BIN"

for f in "$@"; do
  if [[ "$cmd" == "test" ]]; then
    ( cd "src/$f" && "$GO" "$cmd" )
  else
    ( cd "src/$f" && "$GO" "$cmd" -buildvcs=false -o "$RESULT_BIN/$f" )
  fi
done

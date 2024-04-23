#!/bin/bash

# test replayer on known archive db

REPLAYER_DIR=src/app/replayer
REPLAYER_APP=_build/default/src/app/replayer/replayer.exe
PG_CONN=postgres://postgres:postgres@localhost:5433/archive

while [[ "$#" -gt 0 ]]; do case $1 in
  -d|--dir) REPLAYER_DIR="$2"; shift;;
  -a|--app) REPLAYER_APP="$2"; shift;;
  -p| --pg) PG_CONN="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

function report () {
 if [[ $1 == 0 ]]; then
     echo SUCCEEDED
 else
     echo FAILED
 fi
}

echo "Running replayer"
$REPLAYER_APP --archive-uri $PG_CONN --input-file $REPLAYER_DIR/test/input.json

RESULT=$?

report $RESULT

exit $RESULT

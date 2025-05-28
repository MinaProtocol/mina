#!/bin/bash


# test replayer on known archive db
set -x

REPLAY="v0"
ARCHIVE_URL="https://storage.googleapis.com/o1labs-ci-test-data/replay/$REPLAY/archive_db.sql"
PRECOMPUTED_BLOCKS="https://storage.googleapis.com/o1labs-ci-test-data/replay/$REPLAY/precomputed_blocks.tar.xz"

INPUT_FILE=src/test/archive/sample_db/replayer_input_file.json
REPLAYER_APP=_build/default/src/app/replayer/replayer.exe
PG_CONN=postgres://postgres:postgres@localhost:5432/archive

while [[ "$#" -gt 0 ]]; do case $1 in
  -i|--input-file) INPUT_FILE="$2"; shift;;
  -a|--app) REPLAYER_APP="$2"; shift;;
  -p|--pg) PG_CONN="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

pushd "src/test/archive/sample_db"
wget "$ARCHIVE_URL"
wget "$PRECOMPUTED_BLOCKS"
popd

function report () {
 if [[ $1 == 0 ]]; then
     echo SUCCEEDED
 else
     echo FAILED
 fi
}

echo "Running replayer"
$REPLAYER_APP --archive-uri $PG_CONN --input-file $INPUT_FILE

RESULT=$?

report $RESULT

exit $RESULT

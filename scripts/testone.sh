#!/bin/bash
set -e

# File assumes tat you are running the program at the program at the root directory of the coda repo

if [[ "$#" -eq "0" ]]; then 
    echo "This script needs at least one argument, TEST-FILE, to run"
    exit 1
fi

if [[ "$DUNE_PROFILE" -eq "" ]]; then
    DUNE_PROFILE=dev
fi

ABSOLUTE_FILE_PATH="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"

cd src
TEST_FILE=${ABSOLUTE_FILE_PATH#"$(pwd)/"}


DIRPATH=$(dirname "$TEST_FILE")
LIBRARY_NAME=$(basename "$DIRPATH")

TEST_RUNNER_PROG="$DIRPATH/.$LIBRARY_NAME.inline-tests/inline_test_runner_$LIBRARY_NAME.exe"
if [[ "$#" -eq "1" ]]; then 
    TEST_CASE="$TEST_FILE" 
else 
    TEST_CASE="$TEST_FILE:$2"
fi
ulimit -s 65532 && (ulimit -n 10240 || true) && \
dune exec "$TEST_RUNNER_PROG" --profile=$DUNE_PROFILE --display short -- \
    inline-test-runner "$LIBRARY_NAME" \
    -only-test "$TEST_CASE"

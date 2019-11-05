set -e

# File assumes tat you are running the program at the program at the root directory of the coda repo

if [[ "$DUNE_PROFILE" -eq "" ]]; then
    DUNE_PROFILE=dev
fi

ABSOLUTE_FILE_PATH="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"

cd src
TEST_FILE=${ABSOLUTE_FILE_PATH#"$(pwd)/"}


DIRPATH=$(dirname $TEST_FILE)
LIBRARY_NAME=$(basename $DIRPATH)

TEST_RUNNER_PROG="$DIRPATH/.$LIBRARY_NAME.inline-tests/run.exe"
if [[ "$#" -eq "1" ]]; then 
    TEST_CASE="$TEST_FILE" 
else 
    TEST_CASE="$TEST_FILE:$2"
fi
ulimit -s 65532 && (ulimit -n 10240 || true) && \
dune exec $TEST_RUNNER_PROG -- \
    inline-test-runner $LIBRARY_NAME \
    -only-test $TEST_CASE

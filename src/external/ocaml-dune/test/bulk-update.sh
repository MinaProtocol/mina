#!/bin/bash

# This scripts aims to make it easier to do a bulk update of all the
# tests. Simply run it in a terminal and fix the test that's currently
# failing. The script will automatically switch to the next test when
# the current test succeeds. It uses inotifywait to detect changes to
# the test.

DUNE=_build/default/bin/main_dune.exe

LIST=$(mktemp)
trap "rm -f $LIST" EXIT

echo "Computing the list of failing tests..."
$DUNE runtest test/blackbox-tests \
      --diff-command "echo >> $LIST" &> /dev/null
TESTS=$(cat $LIST |cut -d/ -f4 |sed 's/^//')
rm -f $LIST

count=0
for t in $TESTS; do
    let count++
done

i=1
for t in $TESTS; do
    n=0
    while true; do
        clear
        let n++
        title="[$i/$count] $t (run $n)"
        echo "$title"
        echo "${title//?/=}"
        echo
        $DUNE build @test/blackbox-tests/$t && break
        inotifywait $(find test/blackbox-tests/test-cases/$t -type d) \
                    -e modify,attrib,close_write,move,create,delete
    done
done

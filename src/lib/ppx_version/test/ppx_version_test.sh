#!/bin/bash

set -u

for f in test/*ml
do
    $1 --cookie 'library-name="ppx_version_test"' \
    -o /dev/null 2>&1 \
    --impl $f \
    -corrected-suffix .ppx-corrected \
    -diff-cmd -;
    if [ $? -eq 0 ]; then
        echo PASS: $f;
    else
        echo FAIL: $f;
    fi
done


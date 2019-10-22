#!/usr/bin/env bash

set -euo pipefail

for _ in $(seq 1 10)
do
    echo hello
    echo '{"timestamp":"2019-10-22 00:41:37.963244Z","level":"Info","source":{"module":"Test_script","location":"File \"src/lib/child_processes/tester.sh\", line 321, characters 11-98"},"message":"test of json logging passthrough","metadata":{}}' 1>&2
    sleep 0.1
done

if [ "$1" = "loop" ]
then
    while true
    do
        sleep 100
    done
fi

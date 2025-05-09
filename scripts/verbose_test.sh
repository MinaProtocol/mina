#!/usr/bin/env bash

cat /dev/null > test_results.txt

echo "TESTING..."
for exe in $(find _build/default -type f -name run.exe)
do
  module=$(echo "$exe" | sed -e 's/^.\+\.\(.\+\)\.inline-tests\/run\.exe/\1/')
  echo "  - $module"
  "$exe" inline-test-runner "$module" -verbose >> test_results.txt
done

cat test_results.txt | grep 'File' | sort -t '(' -k 2 -g

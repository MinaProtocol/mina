#!/bin/bash

set -euo pipefail

echo "Listing perf files in /workdir:"
ls -lh /workdir/*.perf

echo "Printing contents of each perf file:"
for f in /workdir/*.perf; do
  echo "--- $f ---"
  cat "$f"
  echo
  echo "-------------"
done

echo "Sending perf data to InfluxDB"

cat /workdir/*.perf | influx write
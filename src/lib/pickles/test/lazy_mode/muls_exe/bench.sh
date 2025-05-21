#!/bin/bash

## usage: ./bench.sh <mode>
## mode: "lazy" or "eager"

process_name="muls.exe"
interval=0.5  

# Activate virtual environment if needed
# source ~/psenv/bin/activate

# Start the process
dune exec ./muls.exe $1 &

# Wait for the process to start and get its PID
while true; do
  if pid=$(pgrep -x "$process_name"); then
    echo "$pid"
    # Record CPU and memory usage to a log file
    psrecord $pid --log "$1-$pid.txt"
    break
  fi
  sleep "$interval"
done
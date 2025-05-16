#!/bin/bash

## usage: ./bench.sh <mode>
## mode: "lazy" or "eager"

process_name="chunks2.exe"
interval=0.5  


dune exec ./chunks2.exe $1 &


while true; do
  if pid=$(pgrep -x "$process_name"); then
    echo "$pid"
    psrecord $pid --plot $1-"$pid".png
    exit 0
  fi
  sleep "$interval"
done

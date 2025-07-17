#!/bin/bash

CPU_MAX_FILE="/sys/fs/cgroup/system.slice/docker.service/cpu.max"
if [[ ! -f $CPU_MAX_FILE ]]; then
  echo "Error: $CPU_MAX_FILE not found"
  exit 1
fi

read -r CURRENT_QUOTA CURRENT_PERIOD < "$CPU_MAX_FILE"

if [[ "$CURRENT_QUOTA" == "max" ]]; then
  echo "CPU is currently unlimited. Assuming default period 100000 us"
  CURRENT_PERIOD=100000
fi

if ! [[ "$CURRENT_PERIOD" =~ ^[0-9]+$ ]]; then
  echo "Error: Invalid CPU period: $CURRENT_PERIOD"
  exit 1
fi

FIVE_PERCENT=$((CURRENT_PERIOD * 5 / 100))

for CONTAINER_ID in $(docker ps -q); do
  echo "Limiting container $CONTAINER_ID to 5% CPU"
  docker update --cpu-period="$CURRENT_PERIOD" --cpu-quota="$FIVE_PERCENT" "$CONTAINER_ID"
done

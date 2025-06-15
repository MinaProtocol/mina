#!/usr/bin/env bash

# this test does the following: 
# 1. starts `mock_snark_work_coordinator.exe`, which reads a list of predefined 
# specs from a folder, and then starts a work partitioner to distribute jobs 
# being seen;
# 2. starts multiple snark workers, all of them pulling jobs from the mock 
# coordinator;
# 3. Once every proofs arrive at mock coordinator, it will immediately run 
# verifier on it to test the correctness of the proof;
# 4. Once the mock coordinator verified every proof predefined, it will exit
# with exit code 0

NUM_WORKERS=0

while true; do
  # Random port between 1025 and 65535
  port=$(( ( RANDOM << 15 | RANDOM ) % 64511 + 1025 ))

  # Check if port is in use
  if ! ss -tuln | awk '{print $5}' | grep -q ":$port\$"; then
    MOCK_COORDINATOR_PORT=$port
    break
  fi
done

cd $(git root)

dune exec \
  src/app/mock_snark_work_coordinator/mock_snark_work_coordinater.exe \
  -- \
  --coordinator-port $MOCK_COORDINATOR_PORT \
  --dumped-spec-path $DUMPED_SPEC_PATH \
  &

MOCK_COORDINATOR=$!

for i in $(seq 1 $NUM_WORKERS); do
  dune exec \
    src/app/cli/src/mina.exe \
    -- \
    internal snark-worker \
    --daemon-address 127.0.0.1:$MOCK_COORDINATOR_PORT \
    &
done

waitpid $MOCK_COORDINATOR

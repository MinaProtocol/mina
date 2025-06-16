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

NUM_WORKERS=1
# NOTE: have a proper sleep so when worker wakes up the coordinator is ready 
WORKER_SLEEP=60s

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

# Without `MINA_USE_DUMMY_VERIFIER=1`:
# Error: No implementations provided for the following modules:
#          Foreign referenced from /nix/store/0qd7g68imp2csmr22l8waxp0242bcv57-rpc_parallel-v0.14.0/lib/ocaml/4.14.2/site-lib/rpc_parallel/rpc_parallel.cmxa(Rpc_parallel__Utils)
MINA_USE_DUMMY_VERIFIER=1 dune exec \
  src/test/mock_snark_work_coordinator/mock_snark_work_coordinater.exe \
  -- \
  --coordinator-port $MOCK_COORDINATOR_PORT \
  --dumped-spec-path $DUMPED_SPEC_PATH \
  &

MOCK_COORDINATOR_PID=$!

{
  SNARK_WORKER_PIDS=()
  echo "Sleeping for $WORKER_SLEEP before spawning workers"
  sleep $WORKER_SLEEP
  echo "Start spawning workers"

  for i in $(seq 1 $NUM_WORKERS); do
    {
      dune exec \
        src/app/cli/src/mina.exe \
        -- \
        internal snark-worker \
        --daemon-address 127.0.0.1:$MOCK_COORDINATOR_PORT
    } &
  SNARK_WORKER_PIDS+=($!)  # Capture PID of the background job
  done
  for pid in "${SNARK_WORKER_PIDS[@]}"; do
    wait "$pid"
  done
} &
SNARK_WORKER_GROUPS_PID=$!

wait $MOCK_COORDINATOR_PID
wait $SNARK_WORKER_GROUPS_PID

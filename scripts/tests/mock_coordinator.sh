#!/usr/bin/env bash

# NOTE: please run this with devnet build

# this test does the following: 
# 1. starts `mock_snark_work_coordinator.exe`, which reads a list of predefined 
# specs from a folder, and then starts a work partitioner to distribute jobs 
# being seen;
# 2. starts multiple snark workers, all of them pulling jobs from the mock 
# coordinator;
# 3. Once every proofs arrive at mock coordinator, run a separate verifier on 
# them to verify all of them.

NUM_WORKERS=5

# NOTE: Sleep is needed so when worker wakes up the coordinator is ready 
WORKER_SLEEP_PER_SPEC_SEC=1

echo "DUMPED_SPEC_PATH = ${DUMPED_SPEC_PATH:?DUMPED_SPEC_PATH is not set, exiting}"
echo "PROOF_OUTPUT_PATH = ${PROOF_OUTPUT_PATH:?PROOF_OUTPUT_PATH is not set, exiting}"

NUM_SPECS=`ls -1 ${DUMPED_SPEC_PATH} | wc -l`

WORKER_TOTAL_SLEEP=$((WORKER_SLEEP_PER_SPEC_SEC * NUM_SPECS + 20))

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

./_build/default/src/test/mock_snark_work_coordinator/mock_snark_work_coordinator.exe \
  --coordinator-port $MOCK_COORDINATOR_PORT \
  --dumped-spec-path $DUMPED_SPEC_PATH \
  --output-folder $PROOF_OUTPUT_PATH \
  --proof-batch-size 100 \
  &

MOCK_COORDINATOR_PID=$!

{
  SNARK_WORKER_PIDS=()
  echo "Sleeping for ${WORKER_TOTAL_SLEEP}s before spawning workers"
  sleep $WORKER_TOTAL_SLEEP
  for i in $(seq 1 $NUM_WORKERS); do
    {
      echo "Start worker $i"
      ./_build/default/src/app/cli/src/mina.exe \
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

for file in $PROOF_OUTPUT_PATH/*; do
  if [ -f "$file" ]; then
    echo Verifying proof at $file ...
    cat $file \
      | ./_build/default/src/app/cli/src/mina.exe internal run-verifier \
      --mode transaction \
      --format json
  fi
done

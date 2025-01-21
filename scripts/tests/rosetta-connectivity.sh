#!/usr/bin/env bash

# end to end test for rosetta connectivity with given network 
set -x
CLEAR='\033[0m'
RED='\033[0;31m'

NETWORK=devnet
TIMEOUT=900

while [[ "$#" -gt 0 ]]; do case $1 in
  -n|--network) NETWORK="$2"; shift;;
  -t|--tag) TAG="$2"; shift;;
  --timeout) TIMEOUT="$2"; shift;;
  -h|--help) usage; exit 0;;
  *) echo "Unknown parameter passed: $1"; usage; exit 1;;
esac; shift; done


function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 [-t docker-tag] [-n network]"
  echo "  -t, --version             The version to be used in the docker image tag"
  echo "  -n, --network             The network configuration to use (devnet or mainnet). Default=$NETWORK"
  echo "  -h, --help                Show help"
  echo ""
  echo "Example: $0 --network devnet --tag 3.0.3-bullseye-berkeley "
  
}

if [[ -z "$TAG" ]]; then usage "Docker tag is not set!"; usage; exit 1; fi;

container_id=$(docker run -d --env MINA_NETWORK=$NETWORK gcr.io/o1labs-192920/mina-rosetta:$TAG-$NETWORK )

stop_docker() {
    { docker stop "$container_id" ; docker rm "$container_id" ; } || true
}

trap stop_docker ERR

# Command to run the process
process_command="docker logs $container_id -f"

# Pattern to wait for in the output
pattern="Added block with state hash"

# Timeout duration in seconds
timeout_duration=$TIMEOUT

# Required number of matches
required_matches=10

# Count of pattern matches
match_count=0

# Start time
start_time=$(date +%s)

# Wait timeout for next line in output
next_line_timeout=60

# Run the rosetta docker and check its output
while  IFS= read -t $next_line_timeout -r line; do
    # Get the current time
    current_time=$(date +%s)
    
    # Check if the timeout has been exceeded
    elapsed_time=$((current_time - start_time))
    if [ "$elapsed_time" -ge "$timeout_duration" ]; then
        echo "Timeout reached! The pattern ('$pattern') was not found $required_matches times."
        exit 1
    fi

    # If the pattern is found, increment the match count
    if [[ "$line" =~ $pattern ]]; then
        match_count=$((match_count+1))
        echo "Pattern found ($match_count of $required_matches): $line"
    fi

    # If the required number of matches is reached, exit the loop
    if [ "$match_count" -ge "$required_matches" ]; then
        echo "Pattern found $required_matches times. Exiting..."
        break
    fi
done < <($process_command)

stop_docker

# Check if we met the required match count
if [ "$match_count" -ge "$required_matches" ]; then
    echo "Successfully found the pattern ('$pattern') $required_matches times."
    exit 0
else
    echo "Failed to find the pattern ('$pattern') $required_matches times within the timeout."
    exit 1
fi
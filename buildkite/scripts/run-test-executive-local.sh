#!/bin/bash
set -oe pipefail -x

function cleanup
{
  remove_active_stacks() {
      for stack in $(docker stack ls --format "{{.Name}}"); do
          echo "Removing stack: $stack"
          docker stack rm $stack
      done
  }
  while [[ $(docker stack ls | wc -l) -gt 1 ]]; do
      echo "Active Docker stacks found. Removing them..."
      remove_active_stacks
      sleep 5
  done
}

# Set up a local docker swarm
# Check if the current host is part of a Docker Swarm
if docker info --format '{{.Swarm.LocalNodeState}}' | grep -q 'inactive'; then
    docker swarm init --advertise-addr 127.0.0.1
fi

cleanup

# Export the variables to be used later in the Makefile target
DOCKER_REPO="$2"
export TEST_NAME="$1"
export MINA_IMAGE="$DOCKER_REPO/mina-daemon:$MINA_DOCKER_TAG-devnet-generic"
export ARCHIVE_IMAGE="$DOCKER_REPO/mina-archive:$MINA_DOCKER_TAG-devnet"

if [[ "${TEST_NAME:0:15}" == "block-prod-prio" ]] && [[ "$RUN_OPT_TESTS" == "" ]]; then
  echo "Skipping $TEST_NAME"
  exit 0
fi

git config --global --add safe.directory /workdir

source buildkite/scripts/debian/update.sh --verbose

source buildkite/scripts/debian/install.sh "mina-test-executive"

# This should be shared with a local UX
make -C ../../ run-test-executive

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

TEST_NAME="$1"

MINA_IMAGE="gcr.io/o1labs-192920/mina-daemon:$MINA_DOCKER_TAG-devnet"
ARCHIVE_IMAGE="gcr.io/o1labs-192920/mina-archive:$MINA_DOCKER_TAG"

if [[ "${TEST_NAME:0:15}" == "block-prod-prio" ]] && [[ "$RUN_OPT_TESTS" == "" ]]; then
  echo "Skipping $TEST_NAME"
  exit 0
fi

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

rm -f /etc/apt/sources.list.d/hashicorp.list

apt-get update
apt-get install -y git apt-transport-https ca-certificates tzdata curl

git config --global --add safe.directory /workdir

echo "deb [trusted=yes] https://apt.releases.hashicorp.com $MINA_DEB_CODENAME main" | tee /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y "terraform" "docker" "docker-compose-plugin" "docker-ce"

source buildkite/scripts/debian/install.sh "mina-test-executive"

mina-test-executive local "$TEST_NAME" \
  --mina-image "$MINA_IMAGE" \
  --archive-image "$ARCHIVE_IMAGE" \
  | tee "$TEST_NAME.local.test.log" \
  | mina-logproc -i inline -f '!(.level in ["Debug", "Spam"])'

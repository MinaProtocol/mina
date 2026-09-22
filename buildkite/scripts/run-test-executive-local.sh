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
DOCKER_REPO="$2"
MINA_DOCKER_NAME="mina-daemon"
MINA_ARCHIVE_DOCKER_NAME="mina-archive"


# Use the short-hash "HASHTAG" image names: that is what IntegrationTestDockerImages
# builds and saves to the Hetzner CI cache (<githash>-<codename>-<network>[-generic]).
# Those images are built --load-only and never pushed, so the swarm must deploy
# exactly the tag we load from the cache; the full version tag exists neither
# locally nor in any registry.
MINA_IMAGE="$DOCKER_REPO/$MINA_DOCKER_NAME:${GITHASH}-${MINA_DEB_CODENAME}-devnet-generic"
ARCHIVE_IMAGE="$DOCKER_REPO/$MINA_ARCHIVE_DOCKER_NAME:${GITHASH}-${MINA_DEB_CODENAME}-devnet"

# Load both images from the shared CI cache instead of pulling them from the
# registry. A cache miss leaves the image absent and the swarm deploy fails,
# which is the intended signal that IntegrationTestDockerImages did not run.
./buildkite/scripts/docker/load_from_cache.sh "$MINA_IMAGE" \
  || echo "cache miss for $MINA_IMAGE"
./buildkite/scripts/docker/load_from_cache.sh "$ARCHIVE_IMAGE" \
  || echo "cache miss for $ARCHIVE_IMAGE"

if [[ "${TEST_NAME:0:15}" == "block-prod-prio" ]] && [[ "$RUN_OPT_TESTS" == "" ]]; then
  echo "Skipping $TEST_NAME"
  exit 0
fi

git config --global --add safe.directory /workdir

source buildkite/scripts/debian/update.sh --verbose

source buildkite/scripts/debian/install.sh "mina-test-executive"

mina-test-executive local "$TEST_NAME" \
  --mina-image "$MINA_IMAGE" \
  --archive-image "$ARCHIVE_IMAGE" \
  | tee "$TEST_NAME.local.test.log" \
  | mina-logproc -i inline -f '!(.level in ["Debug", "Spam"])'

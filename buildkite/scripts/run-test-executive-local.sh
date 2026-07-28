#!/bin/bash
set -oe pipefail -x

function cleanup
{
  # Dump each swarm service's logs (incl. the seed daemon container) before the
  # stack is removed, so CI can see why a node failed to initialise. Files match
  # the <test>*.local.test.log artifact glob.
  if [[ -n "${TEST_NAME:-}" ]]; then
    for stack in $(docker stack ls --format "{{.Name}}"); do
      for svc in $(docker stack services "$stack" --format "{{.Name}}" 2>/dev/null); do
        echo "Dumping service logs for $svc"
        docker service logs --raw "$svc" \
          >"${TEST_NAME}-${svc}.local.test.log" 2>&1 || true
      done
    done
  fi
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


# Use the short-hash "HASHTAG" image names — that is what the
# IntegrationTestDockerImages job builds and saves to the Hetzner CI cache
# (<githash>-<codename>-<network>[-generic]). The images are built --load-only
# (never pushed to a registry), so the swarm must deploy the exact tag we load
# from the cache; pointing test_executive at the full version tag would fail
# because that tag exists neither locally nor in the registry.
MINA_IMAGE="$DOCKER_REPO/$MINA_DOCKER_NAME:${GITHASH}-${MINA_DEB_CODENAME}-devnet-generic"
ARCHIVE_IMAGE="$DOCKER_REPO/$MINA_ARCHIVE_DOCKER_NAME:${GITHASH}-${MINA_DEB_CODENAME}-devnet"

if [[ "${TEST_NAME:0:15}" == "block-prod-prio" ]] && [[ "$RUN_OPT_TESTS" == "" ]]; then
  echo "Skipping $TEST_NAME"
  exit 0
fi

git config --global --add safe.directory /workdir

# Free docker disk before loading the (~GB-scale) daemon/archive images.
# Without this the agent can run out of space during `docker load`, which
# takes the docker daemon down mid-test ("Cannot connect to the Docker
# daemon"). THRESHOLD=0 forces the prune; the script is concurrency-safe
# (dangling/unused only, keeps tagged images for co-located jobs).
DISK_PRUNE_THRESHOLD=0 ./buildkite/scripts/docker/disk-cleanup.sh

# Load the daemon/archive images from the shared Hetzner CI cache instead of
# pulling them from the registry, keeping the integration tests off the docker
# registry / GAR path. On a cache miss the deploy would fail (the images are
# never pushed), which is the intended signal that the build job did not run.
./buildkite/scripts/docker/load_from_cache.sh "$MINA_IMAGE" \
  || echo "cache miss for $MINA_IMAGE"
./buildkite/scripts/docker/load_from_cache.sh "$ARCHIVE_IMAGE" \
  || echo "cache miss for $ARCHIVE_IMAGE"

source buildkite/scripts/debian/update.sh --verbose

source buildkite/scripts/debian/install.sh "mina-test-executive"

# Continuously snapshot each swarm service's container logs while the test runs,
# so the seed daemon's own output survives test_executive's teardown and can be
# collected as a CI artifact (the polling log engine can't capture a daemon that
# never finishes initialising). The latest non-empty snapshot per service is
# kept once the stack is removed.
( while true; do
    for stack in $(docker stack ls --format "{{.Name}}" 2>/dev/null); do
      for svc in $(docker stack services "$stack" --format "{{.Name}}" 2>/dev/null)
      do
        logs=$(docker service logs --raw "$svc" 2>/dev/null) || continue
        [ -n "$logs" ] && printf '%s\n' "$logs" >"${TEST_NAME}-${svc}.local.test.log"
      done
    done
    sleep 20
  done ) &

export MINA_PROFILE="devnet"
mina-test-executive local "$TEST_NAME" \
  --mina-image "$MINA_IMAGE" \
  --archive-image "$ARCHIVE_IMAGE" \
  | tee "$TEST_NAME.local.test.log" \
  | mina-logproc -i inline -f '!(.level in ["Debug", "Spam"])'

#!/bin/bash

# start berkeley daemon as seed, see if PR branch daemon can sync to it

# don't exit if docker download fails
set +e

function get_shas {
  SHAS=$(git log -n 10 --format="%h" --abbrev=7 --no-merges)
}

function image_tag {
    SHA=$1
    IMAGE_TAG="$SHA-bullseye-berkeley"
}

function download-docker {
   SHA=$1
   image_tag $SHA
   docker pull gcr.io/o1labs-192920/mina-daemon:$IMAGE_TAG
}

function try_docker_shas {
    DOCKER_SHAS=$1
    GOT_DOCKER=0

    for sha in $DOCKER_SHAS; do
	download-docker $sha
	if [ $? -eq 0 ] ; then
	    GOT_DOCKER=1
	    image_tag $sha
	    break
	else
	    echo "No docker available for SHA=$sha"
	fi
    done
}

function image_id {
    TAG=$1
    IMAGE_ID=$(docker images | grep $TAG | head -n 1 | awk '{print $3}')
}

case "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" in
  develop) ;;
  *)
      echo "PR is not against develop, not running the berkeley compatibility test"
      exit 0
esac

### Download docker images

CURR_BRANCH=$(git branch --show-current)
echo "Current branch is $CURR_BRANCH"

echo "Checking out berkeley branch"
git checkout berkeley
git pull

echo "Getting berkeley docker"
get_shas
try_docker_shas "$SHAS"

if [ $GOT_DOCKER -eq 1 ] ; then
    echo "Got berkeley docker"
else
    echo "Could not find berkeley docker"
    exit 1
fi

BERKELEY_IMAGE_TAG=$IMAGE_TAG

echo "Checking out PR branch"
git checkout $CURR_BRANCH

echo "Getting PR docker"
get_shas
try_docker_shas "$SHAS"

if [ $GOT_DOCKER -eq 1 ] ; then
    echo "Got docker for PR branch"
else
    echo "Could not find a docker for PR branch"
    exit 1
fi

PR_IMAGE_TAG=$IMAGE_TAG

echo "Berkeley image tag:" $BERKELEY_IMAGE_TAG
echo "PR image tag:" $PR_IMAGE_TAG

image_id $BERKELEY_IMAGE_TAG
BERKELEY_IMAGE_ID=$IMAGE_ID

echo "Berkeley image id:" $BERKELEY_IMAGE_ID

image_id $PR_IMAGE_TAG
PR_IMAGE_ID=$IMAGE_ID

echo "PR image id:" $PR_IMAGE_ID

### Run docker images

# generate libp2p keypair, commit container
BERKELEY_CONTAINER=$(docker run -d -e MINA_LIBP2P_PASS='' --entrypoint mina $BERKELEY_IMAGE_ID libp2p generate-keypair --privkey-path libp2p)

# allow time for mina to start, key to be written
sleep 10

BERKELEY_DOCKER="berkeley_docker"

docker commit $BERKELEY_CONTAINER "mina_ci":$BERKELEY_DOCKER

image_id $BERKELEY_DOCKER
BERKELEY_COMMITTED_IMAGE_ID=$IMAGE_ID

echo "Berkeley committed image id:" $BERKELEY_COMMITTED_IMAGE_ID

BERKELEY_LIBP2P_PEER_ID=$(docker run -e MINA_LIBP2P_PASS='' --entrypoint mina $BERKELEY_COMMITTED_IMAGE_ID libp2p dump-keypair --privkey-path libp2p | awk -F , '(NR==2){print $3}')

echo "Berkeley libp2p peer id:" $BERKELEY_LIBP2P_PEER_ID

BERKELEY_SEED_CONTAINER=$(docker run --entrypoint mina -d -e MINA_LIBP2P_PASS='' $BERKELEY_COMMITTED_IMAGE_ID daemon --libp2p-keypair ./libp2p --seed)

# allow time for berkeley seed daemon to boot
sleep 20

BERKELEY_SYNCED=0
BERKELEY_REST_SERVER="http://127.0.0.1:3085/graphql"

while [ $BERKELEY_SYNCED -eq 0 ]; do
    SYNC_STATUS=$(docker container exec -it $BERKELEY_SEED_CONTAINER \
                  curl -g -X POST -H "Content-Type: application/json" -d '{"query":"query { syncStatus }"}' ${BERKELEY_REST_SERVER})
    BERKELEY_SYNCED=$(echo ${SYNC_STATUS} | grep -c "SYNCED")
    sleep 5
done

echo "Berkeley seed done bootstrapping"

#!/bin/bash

# start mainline branch daemon as seed, see if PR branch daemon can sync to it

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

function gen_libp2p_keypair {
    IMAGE_ID=$1
    DOCKER_TAG=$2

    CONTAINER=$(docker run -d -e MINA_LIBP2P_PASS='' --entrypoint mina $IMAGE_ID libp2p generate-keypair --privkey-path libp2p)

    # allow time for key to be written
    sleep 10

    docker commit $CONTAINER "mina_ci":$DOCKER_TAG

    image_id $DOCKER_TAG

    COMMITTED_IMAGE_ID=$IMAGE_ID

    echo "Committed image:" $DOCKER_TAG:$COMMITTED_IMAGE_ID
}

function boot_and_sync {
    IMAGE_ID=$1
    EXTERNAL_PORT=$2
    REST_PORT=$3
    PEER_ID=$4
    PEER_PORT=$5

    if [ ! -z $PEER_ID ] && [ ! -z $PEER_PORT ]; then
	echo "Running with peer" $PEER_ID "on port" $PEER_PORT
	PEER_FLAG="--peer /ip4/127.0.0.1/tcp/"$PEER_PORT"/p2p/"$PEER_ID
	SEED_FLAG=""
    else
	echo "Running as seed"
	PEER_FLAG=""
	SEED_FLAG="--seed"
    fi

    DAEMON_CONTAINER=$(docker run --entrypoint mina -d -e MINA_LIBP2P_PASS='' $IMAGE_ID daemon \
		       --libp2p-keypair ./libp2p --external-port $EXTERNAL_PORT --rest-port $REST_PORT $PEER_FLAG $SEED_FLAG)

    # allow time to boot
    sleep 20

    SYNCED=0
    REST_SERVER="http://127.0.0.1:$REST_PORT/graphql"

    while [ $SYNCED -eq 0 ]; do
	SYNC_STATUS=$(docker container exec -it $DAEMON_CONTAINER \
			     curl -g -X POST -H "Content-Type: application/json" -d '{"query":"query { syncStatus }"}' ${REST_SERVER})

    # print logs
    docker container logs $DAEMON_CONTAINER --tail 10

    # "connection refused" until GraphQL server up
    GOT_SYNC_STATUS=$(echo ${SYNC_STATUS} | grep "syncStatus")
    if [ ! -z $GOT_SYNC_STATUS ]; then
        echo $(date +'%Y-%m-%d %H:%M:%S') ". Sync status:" $GOT_SYNC_STATUS
    fi

	# "connection refused" until GraphQL server up
	GOT_SYNC_STATUS=$(echo ${SYNC_STATUS} | grep "syncStatus")
	if [ ! -z $GOT_SYNC_STATUS ]; then
	    echo "Sync status:" $GOT_SYNC_STATUS
	fi

	SYNCED=$(echo ${SYNC_STATUS} | grep -c "SYNCED")
	sleep 5
    done
}

function rm_docker_container {
    IMAGE_ID=$1

    DOCKER_CONTAINER=$(docker ps -a | grep $IMAGE_ID | awk '{print $1}')

    docker kill $DOCKER_CONTAINER
    docker rm $DOCKER_CONTAINER
}

### start of code

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <mainline-branch>"
    exit 1
fi

MAINLINE_BRANCH=$1

case "$BUILDKITE_PULL_REQUEST_BASE_BRANCH" in
  develop) ;;
  *)
      echo "PR is not against develop, not running the $MAINLINE_BRANCH compatibility test"
      exit 0
esac

### Download docker images

echo "Current branch is $BUILDKITE_BRANCH"

echo "Checking out $MAINLINE_BRANCH branch"
git checkout $MAINLINE_BRANCH
git pull

echo "Getting $MAINLINE_BRANCH docker"
get_shas
try_docker_shas "$SHAS"

if [ $GOT_DOCKER -eq 1 ] ; then
    echo "Got $MAINLINE_BRANCH docker"
else
    echo "Could not find $MAINLINE_BRANCH docker"
    exit 1
fi

MAIN_BRANCH_IMAGE_TAG=$IMAGE_TAG

CURR_BRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)

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

echo "${MAINLINE_BRANCH} image tag:" $MAIN_BRANCH_IMAGE_TAG
echo "PR image tag:" $PR_IMAGE_TAG

image_id $MAIN_BRANCH_IMAGE_TAG
MAIN_BRANCH_IMAGE_ID=$IMAGE_ID

echo "${MAINLINE_BRANCH} image id:" $MAIN_BRANCH_IMAGE_ID

image_id $PR_IMAGE_TAG
PR_IMAGE_ID=$IMAGE_ID

echo "PR image id:" $PR_IMAGE_ID

### Run docker images

# generate libp2p keypair for mainline branch
gen_libp2p_keypair $MAIN_BRANCH_IMAGE_ID "${MAINLINE_BRANCH}_docker"

MAIN_BRANCH_COMMITTED_IMAGE_ID=$COMMITTED_IMAGE_ID
MAIN_BRANCH_LIBP2P_PEER_ID=$(docker run -e MINA_LIBP2P_PASS='' --entrypoint mina $MAIN_BRANCH_COMMITTED_IMAGE_ID \
			  libp2p dump-keypair --privkey-path libp2p | awk -F , '(NR==2){print $3}')

echo "${MAINLINE_BRANCH} libp2p peer id:" $MAIN_BRANCH_LIBP2P_PEER_ID

echo "Booting ${MAINLINE_BRANCH} daemon"
boot_and_sync $MAIN_BRANCH_COMMITTED_IMAGE_ID 8302 3085

echo "${MAINLINE_BRANCH} seed done bootstrapping"

# generate PR libp2p keypair
gen_libp2p_keypair $PR_IMAGE_ID "pr_docker"

PR_COMMITTED_IMAGE_ID=$COMMITTED_IMAGE_ID

echo "Booting PR daemon"

boot_and_sync $PR_COMMITTED_IMAGE_ID 8305 3086 $MAIN_BRANCH_LIBP2P_PEER_ID 8302

echo "PR daemon synced to ${MAINLINE_BRANCH} daemon!"

echo "Removing docker containers"

rm_docker_container $MAIN_BRANCH_COMMITTED_IMAGE_ID
rm_docker_container $PR_COMMITTED_IMAGE_ID

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
    IMAGE_TAG=$1
    IMAGE_ID=$(docker images | grep $IMAGE_TAG | awk '{print $3}')
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

# just to see if this runs at all
docker run  --entrypoint mina $BERKELEY_IMAGE_ID daemon

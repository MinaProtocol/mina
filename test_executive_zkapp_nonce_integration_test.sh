export MINA_DOCKER_TAG=3.1.1-alpha1-lyh-fix-integration-nightly-snark-worker-rpc-bump-e18542e-bullseye

export MINA_IMAGE="gcr.io/o1labs-192920/mina-daemon:$MINA_DOCKER_TAG-berkeley"
export ARCHIVE_IMAGE="gcr.io/o1labs-192920/mina-archive:$MINA_DOCKER_TAG"
export TEST_NAME=zkapps-nonce

docker pull $MINA_IMAGE
docker pull $ARCHIVE_IMAGE

# ./_build/default/src/app/test_executive/test_executive.exe \
# local $TEST_NAME \
# --mina-image=$MINA_IMAGE \
# --archive-image=$ARCHIVE_IMAGE \
# | tee "$TEST_NAME.local.test.log" \
# | ./_build/default/src/app/logproc/logproc.exe -i inline -f '!(.level in ["Spam"])'

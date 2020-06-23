#!/bin/bash

set -eou pipefail
set +x

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <path-to-file> <hit-in-docker-cmd> <miss-in-docker-cmd>"
  exit 1
fi

# download gsutil if it doesn't exist
# TODO: Bake this into the agents
if [[ ! -f /usr/local/google-cloud-sdk/bin/gsutil ]]; then
  echo "Downloading gsutil because it doesn't exist"
  wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-296.0.1-linux-x86_64.tar.gz

  tar -zxf google-cloud-sdk-296.0.1-linux-x86_64.tar.gz -C /usr/local/

  echo "$BUILDKITE_GS_APPLICATION_CREDENTIALS_JSON" > /tmp/gcp_creds.json

  export GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcp_creds.json && /usr/local/google-cloud-sdk/bin/gcloud auth activate-service-account bk-large@o1labs-192920.iam.gserviceaccount.com --key-file /tmp/gcp_creds.json
fi

UPLOAD_BIN=/usr/local/google-cloud-sdk/bin/gsutil
PREFIX=gs://buildkite_k8s/coda/shared
FILE="$1"
HIT_CMD="$2"
MISS_CMD="$3"

set +e
if ! $UPLOAD_BIN cp ${PREFIX}/${FILE} .; then
  set -e
  echo "*** Cache miss -- executing step ***"
  bash -c "$MISS_CMD"
  $UPLOAD_BIN cp ${FILE} ${PREFIX}/${FILE}
else
  set -e
  echo "*** Cache Hit -- skipping step ***"
  bash -c "$HIT_CMD"
fi


#!/bin/bash

set -eou pipefail
set +x

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <path-to-file> <postprocess-run-preprocess-in-docker-cmd>"
  exit 1
fi

# download gsutil if it doesn't exist
# TODO: Bake this into the agents
if [[ ! -f ./google-cloud-sdk/bin/gsutil ]]; then
  echo "Downloading gsutil because it doesn't exist"
  wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-296.0.1-linux-x86_64.tar.gz

  tar -zxf google-cloud-sdk-296.0.1-linux-x86_64.tar.gz -C /usr/local/

  echo "$BUILDKITE_GS_APPLICATION_CREDENTIALS_JSON" > /tmp/gcp_creds.json

  export GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcp_creds.json && /usr/local/google-cloud-sdk/bin/gcloud auth activate-service-account bk-large@o1labs-192920.iam.gserviceaccount.com --key-file /tmp/gcp_creds.json
fi

UPLOAD_BIN=/usr/local/google-cloud-sdk/bin/gsutil
# UPLOAD_BIN=echo
FILE="$1"
CMD="$2"

set +e
$UPLOAD_BIN cp gs://buildkite_k8s/coda/shared/${FILE} . ; echo $? > download_status.txt
set -e

if ! ( exit $(cat download_status.txt) ); then
  echo "*** Cache miss -- executing step ***"
  bash -c "$CMD"
  $UPLOAD_BIN cp ${FILE} gs://buildkite_k8s/coda/shared/${FILE}
else
  echo "*** Cache Hit -- skipping step ***"
fi


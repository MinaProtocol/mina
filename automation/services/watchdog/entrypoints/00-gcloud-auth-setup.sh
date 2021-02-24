#!/bin/bash

set -eo pipefail
set +x

# Activate service account/cluster credentials if provided
if [[ -n $GCLOUD_APPLICATION_CREDENTIALS_JSON && -n $CLUSTER_SERVICE_EMAIL ]]; then
    echo "${GCLOUD_APPLICATION_CREDENTIALS_JSON}" > /tmp/gcp_creds.json

    export GOOGLE_APPLICATION_CREDENTIALS=/tmp/gcp_creds.json && \
        gcloud auth activate-service-account ${CLUSTER_SERVICE_EMAIL} --key-file /tmp/gcp_creds.json

    declare -A k8s_cluster_mappings=(
        ["coda-infra-east"]="us-east1"
        ["coda-infra-east4"]="us-east4"
        ["coda-infra-central1"]="us-central1"
        ["mina-integration-west1"]="us-west1"
    )
    for cluster in "${!k8s_cluster_mappings[@]}"; do
        gcloud container clusters get-credentials "${cluster}" --region "${k8s_cluster_mappings[$cluster]}"
    done
else
    echo "GCLOUD credentials not provided - account authorization deactivated."
fi

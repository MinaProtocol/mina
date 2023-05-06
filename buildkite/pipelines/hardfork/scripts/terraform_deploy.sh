#!/bin/bash
# this script deploys a pre-configured mina network using terraform

set -euo pipefail

##########################################################
# Downloading required files
##########################################################

echo "--- Cloning Mina repository"
git clone https://github.com/MinaProtocol/mina.git
cd ./mina/ && git checkout itn3-testnet-deployment

echo "--- Downloading network node keys"
gsutil -m cp -r gs://hardfork/keys ./automation/terraform/testnets/testworld-2-0/
gsutil cp gs://hardfork/${REQUIRED} ./automation/terraform/testnets/testworld-2-0/

echo "--- Connecting to Google Kubernetes Engine"
gcloud container clusters get-credentials coda-infra-central1 --region us-central1 --project o1labs-192920

##########################################################
# Terraform network deployment
##########################################################

echo "--- Initializing terraform network configuration"
cd ./automation/terraform/testnets/testworld-2-0/ && terraform init

echo "--- Deploying network hardfork"
terraform apply --auto-approve

##########################################################
# Checking deployment status
##########################################################

echo "--- Waiting for mina nodes to come online"

# NAMESPACE="testworld-2-0"

# # Function to check the status of all pods in the namespace
# check_pods_status() {
#   all_running=true
#   for pod in $(kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
#     echo "Pod: $pod"
#     if ! kubectl wait --for=condition=Ready pod/$pod -n $NAMESPACE --timeout=120s > /dev/null 2>&1; then
#       all_running=false
#     fi
#     echo ""
#   done
# }

# # Loop until all pods are running
# while ! check_pods_status; do
#   echo "Not all pods are running. The following pods are not yet running:"
#   kubectl get pods -n $NAMESPACE | awk '$3 != "Running" {print $1}'
#   echo "Sleeping for 1 minute..."
#   sleep 60
# done

# echo "All workloads are running. Hardfork deployment complete!"

echo "Hardfork deployment complete!"
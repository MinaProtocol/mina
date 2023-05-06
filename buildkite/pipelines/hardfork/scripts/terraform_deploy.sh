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

NAMESPACE="testworld-2-0"

# Function to check the status of all workloads in the namespace
check_workloads_status() {
  all_running=true
  for workload in $(kubectl get workloads -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
    echo "Workload: $workload"
    if ! kubectl rollout status workload $workload -n $NAMESPACE; then
      all_running=false
    fi
    echo ""
  done

  # Return true if all workloads are running, false otherwise
  $all_running
}

# Loop until all workloads are running
while ! check_workloads_status; do
  echo "Not all workloads are running. Sleeping for 1 minute..."
  sleep 60
done

echo "All workloads are running. Hardfork deployment complete!"
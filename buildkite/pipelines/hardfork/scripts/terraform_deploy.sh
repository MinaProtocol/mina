#!/bin/bash
# this script deploys a pre-configured mina network using terraform

set -euo pipefail

echo "--- Cloning Mina repository"
git clone https://github.com/MinaProtocol/mina.git
cd ./mina/ && git checkout itn3-testnet-deployment

echo "--- Downloading network node keys"
gsutil -m cp -r gs://hardfork/keys ./automation/terraform/testnets/testworld-2-0/

echo "--- Connecting to Google Kubernetes Engine"
gcloud container clusters get-credentials coda-infra-central1 --region us-central1 --project o1labs-192920

##########################################################
# Terraform network deployment
##########################################################

echo "--- Initializing terraform network configuration"
cd ./automation/terraform/testnets/testworld-2-0/ && terraform init

echo "--- Deploying network hardfork"
terraform apply --auto-approve

echo "--- Waiting for mina nodes to come online"
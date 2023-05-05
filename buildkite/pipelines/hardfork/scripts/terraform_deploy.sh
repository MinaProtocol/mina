#!/bin/bash
# this script deploys a pre-configured mina network using terraform

set -euo pipefail

echo "--- Cloning Mina repository"
git clone https://github.com/MinaProtocol/mina.git

##########################################################
# Terraform network deployment
##########################################################

echo "--- Initializing terraform configuration"

pwd
ls

# cd ./automations/terraform/testnets/testworld-2-0/ && terraform init

echo "--- Deploying hardfork network"


echo "--- Waiting for mina nodes to come online"
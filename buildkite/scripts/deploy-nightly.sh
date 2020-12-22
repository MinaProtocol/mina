#!/bin/bash

# TODO: make sure terraform installed

cd coda-automation/terraform/testnets/nightly
terraform init
terraform destroy -auto-approve
terraform apply -auto-approve


#!/bin/bash

# TODO: make sure terraform installed

source DOCKER_DEPLOY_ENV
DAEMON_TAG="gcr.io/o1labs-192920/coda-daemon:${CODA_VERSION}-${CODA_GIT_HASH}"

ARCHIVE_TAG="gcr.io/o1labs-192920/coda-archive:${CODA_VERSION}-${CODA_GIT_HASH}"

cd automation/terraform/testnets/nightly
terraform init
terraform destroy -auto-approve
terraform apply -var="coda_image=${DAEMON_TAG}" -var="coda_archive_image=${ARCHIVE_TAG}" -auto-approve


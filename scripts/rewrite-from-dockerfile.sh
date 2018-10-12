#!/bin/bash

set -e

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 name version"
fi

project=$(gcloud config get-value project)

perl -i -p -e 's,FROM.*,FROM gcr.io/'$project'/'$1':'$2',' $SCRIPTPATH/../dockerfiles/Dockerfile
perl -i -p -e 's,FROM.*,FROM gcr.io/'$project'/'$1':'$2',' $SCRIPTPATH/../dockerfiles/Dockerfile-coda
perl -i -p -e 's,image:.*,image: gcr.io/'$project'/'$1':'$2',' $SCRIPTPATH/../.circleci/config.yml.jinja

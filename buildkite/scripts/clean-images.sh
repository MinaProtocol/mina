#!/bin/bash

set -eo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <image-age> <dryrun>"
    exit 1
fi

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git apt-transport-https ca-certificates tzdata curl python3 python3-pip wget

cd automation/services/gcloud-cleaner/scripts
pip3 install -r requirements.txt
echo "--- Run Python script to clean images with properties: ${image_age} ${dryrun}"
python3 clean_old_images.py ${image_age} ${dryrun}
#!/bin/bash

KEY_FILE=/var/secrets/google/key.json

if [ ! -f $KEY_FILE ]; then
    echo "Cannot use gsutil for upload as key file cannot be found in $KEY_FILE"
fi

gcloud auth activate-service-account --key-file=$KEY_FILE

gsutil cp $1 $2
#!/bin/bash

gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
gcloud config set project o1labs-192920
gcloud container clusters get-credentials --region us-west1 mina-integration-west1
kubectl config use-context gke_o1labs-192920_us-west1_mina-integration-west1
mina-test-executive cloud $TEST_NAME --mina-image $MINA_IMAGE --archive-image $ARCHIVE_IMAGE $( if [[ $DEBUG_BOOL ]] ; then echo --debug ; fi ) | tee test.log | mina-logproc -i inline -f '!(.level in ["Spam", "Debug"])'

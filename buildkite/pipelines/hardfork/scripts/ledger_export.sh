#!/bin/bash

set -e 
set -o pipefail

# this file exports three ledgers to be used during the hard fork, these ledgers are:
# - staged ledger: this ledger contains all transactions in the current epoch (snarked as well as pending transactions).
# - next-staking ledger: fully snarked ledger from epoch - 1. 
# - current staking ledger: fully snarked ledger from epoch - 2. This active staking distribution is carried forward in the hardfork network.

##########################################################
# CONNECT TO GCLOUD AND MINA NODE WITHIN KUBERNETES
##########################################################

echo
gcloud container clusters get-credentials coda-infra-central1 --region us-central1 --project o1labs-192920

export DATE=$(date +%F_%H%M)
export TARGET_NAMESPACE=berkeley
export TARGET_NODE=$(kubectl get pod --namespace=$TARGET_NAMESPACE | grep seed-1 | grep -o '^\S*')
export EPOCHNUM=$(kubectl exec $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- /bin/bash -c 'mina client status|grep "Best tip consensus time"|grep -o "epoch=[0-9]*"|sed "s/[^0-9]*//g"')
echo


echo "todays date is $DATE"
echo "the current epoch is $EPOCHNUM"
echo

##########################################################
# EXPORT LEDGERS
##########################################################

echo "initializing hard fork ledger export from node $TARGET_NODE within the $TARGET_NAMESPACE network"
echo

echo "....................."
echo

# export staking ledger
echo "initializing staking ledger export..."
kubectl exec $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- /bin/bash -c 'mina ledger export staking-epoch-ledger > staking_epoch_ledger.json'
export STAKING_HASH=$(kubectl exec $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- /bin/bash -c 'mina ledger hash --ledger-file staking_epoch_ledger.json')
export STAKING_MD5=$(kubectl exec $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- /bin/bash -c 'md5sum staking_epoch_ledger.json|cut -d " " -f 1')
echo "staking ledger export is complete!"
echo

echo "staking ledger hash: $STAKING_HASH"
echo "staking ledger MD5: $STAKING_MD5"
echo

echo "....................."
echo

# export next staking ledger
echo "initializing next staking ledger export..."
kubectl exec $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- /bin/bash -c 'mina ledger export next-epoch-ledger > next_epoch_ledger.json'
export NEXT_STAKING_HASH=$(kubectl exec $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- /bin/bash -c 'mina ledger hash --ledger-file next_epoch_ledger.json')
export NEXT_STAKING_MD5=$(kubectl exec $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- /bin/bash -c 'md5sum next_epoch_ledger.json|cut -d " " -f 1')
echo "next staking ledger export is complete!"
echo

echo "next staking ledger hash: $NEXT_STAKING_HASH"
echo "next staking ledger MD5: $NEXT_STAKING_MD5"
echo

echo "....................."
echo

# export staging ledger
echo "initializing staging ledger export..."
kubectl exec $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- /bin/bash -c 'mina ledger export staged-ledger > staged_ledger.json'
export STAGED_HASH=$(kubectl exec $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- /bin/bash -c 'mina ledger hash --ledger-file staged_ledger.json')
export STAGED_MD5=$(kubectl exec $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- /bin/bash -c 'md5sum staged_ledger.json|cut -d " " -f 1')
echo "staging ledger export is complete!"
echo

echo "staging ledger hash: $STAGED_HASH"
echo "staging ledger MD5: $STAGED_MD5"
echo

echo "....................."
echo

##########################################################
# COPY LEDGER FILES TO BUILDKITE AGENT LOCAL STORAGE
##########################################################

export STAKING_FILENAME=staking-"$EPOCHNUM"-"$STAKING_HASH"-"$STAKING_MD5"-"${DATE:: -1}0".json
export NEXT_STAKING_FILENAME=next-staking-"$EPOCHNUM"-"$NEXT_STAKING_HASH"-"$NEXT_STAKING_MD5"-"$DATE".json
export STAGED_FILENAME=staged-"$EPOCHNUM"-"$STAGED_HASH"-"$STAGED_MD5"-"$DATE".json

echo "initializing move of hard fork ledger files to buildkite agent local storage..."
echo "copying staking ledger..."
kubectl exec -i $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- cat ./staking_epoch_ledger.json > ./$STAKING_FILENAME
echo "copying next staking ledger..."
kubectl exec -i $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- cat ./next_epoch_ledger.json > ./$NEXT_STAKING_FILENAME
echo "copying staging ledger..."
kubectl exec -i $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- cat ./staged_ledger.json > ./$STAGED_FILENAME
echo "copying of hard fork ledger files is complete!"
echo

echo "....................."
echo

# verifying md5 match after file copy
echo "confirming integrity of hard fork ledgers using MD5 hash..."
echo

export BUILDKITE_STAKING_MD5=$(md5sum $STAKING_FILENAME|cut -d " " -f 1)
export BUILDKITE_NEXT_STAKING_MD5=$(md5sum $NEXT_STAKING_FILENAME|cut -d " " -f 1)
export BUILDKITE_STAGED_MD5=$(md5sum $STAGED_FILENAME|cut -d " " -f 1)

echo "buildkite staking ledger MD5: $BUILDKITE_STAKING_MD5"
tmpval="Z${BUILDKITE_STAKING_MD5}" ; BUILDKITE_STAKING_MD5="${tmpval}" # convert MD5 to string
tmpval="Z${STAKING_MD5}" ; STAKING_MD5="${tmpval}" # convert MD5 to string

if [[ $BUILDKITE_STAKING_MD5 -eq $STAKING_MD5 ]]
    then
        echo "staking ledger MD5 match confirmed!"
        echo
    else
        echo "staking ledger MD5 values to do match. Aborting..."
        exit 1
fi

echo "buildkite next staking ledger MD5: $BUILDKITE_NEXT_STAKING_MD5"
tmpval="Z${BUILDKITE_NEXT_STAKING_MD5}" ; BUILDKITE_NEXT_STAKING_MD5="${tmpval}" # convert MD5 to string
tmpval="Z${NEXT_STAKING_MD5}" ; NEXT_STAKING_MD5="${tmpval}" # convert MD5 to string

if [[ $BUILDKITE_NEXT_STAKING_MD5 -eq $NEXT_STAKING_MD5 ]]
    then
        echo "staking ledger MD5 match confirmed!"
        echo
    else
        echo "staking ledger MD5 values to do match. Aborting..."
        exit 1
fi

echo "buildkite staged ledger MD5: $BUILDKITE_STAGED_MD5"
tmpval="Z${BUILDKITE_STAGED_MD5}" ; BUILDKITE_STAGED_MD5="${tmpval}" # convert MD5 to string
tmpval="Z${STAGED_MD5}" ; STAGED_MD5="${tmpval}" # convert MD5 to string

if [[ $BUILDKITE_STAGED_MD5 -eq $STAGED_MD5 ]]
    then
        echo "staking ledger MD5 match confirmed!"
        echo
    else
        echo "staking ledger MD5 values to do match. Aborting..."
        exit 1
fi

echo "....................."
echo

##########################################################
# UPLOAD LEDGERS TO GCLOUD
##########################################################

export STORAGE_LOCATION=gs://hardfork/test

echo "uploading hard fork ledger files to Google Cloud storage..."
echo

echo "uploading staking ledger..."
echo
gsutil -o Credentials:gs_service_key_file=$GOOGLE_APPLICATION_CREDENTIALS cp $STAKING_FILENAME $STORAGE_LOCATION
echo

echo "uploading next staking ledger..."
echo
gsutil -o Credentials:gs_service_key_file=$GOOGLE_APPLICATION_CREDENTIALS cp $NEXT_STAKING_FILENAME $STORAGE_LOCATION
echo

echo "uploading staging ledger..."
echo
gsutil -o Credentials:gs_service_key_file=$GOOGLE_APPLICATION_CREDENTIALS cp $STAGED_FILENAME $STORAGE_LOCATION
echo

echo "uploading of hard fork ledgers is complete!"
echo "hard fork ledger files are located at $STORAGE_LOCATION"
echo

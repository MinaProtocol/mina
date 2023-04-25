#!/bin/bash
# this script is to capture the seed data for the current epoch and next epoch, based on the target HARDFORK_BLOCK
# reference: https://docs.minaprotocol.com/node-developers/graphql-api

set -e 
set -o pipefail

##########################################################
# CONNECT TO GCLOUD AND MINA NODE WITHIN KUBERNETES
##########################################################

echo
gcloud container clusters get-credentials coda-infra-central1 --region us-central1 --project o1labs-192920

export DATE=$(date +%F_%H%M)
export TARGET_NAMESPACE=berkeley
export TARGET_NODE=$(kubectl get pod --namespace=$TARGET_NAMESPACE | grep seed-1 | grep -o '^\S*')
export HARDFORK_BLOCK=3903
echo


echo "todays date is $DATE"
echo "the targeted hardfork block is: $HARDFORK_BLOCK"
echo

##########################################################
# GATHER EPOCH SEEDS
##########################################################

# collect the seed data from the current and next epoch
echo "initializing hard fork epoch seed export from node $TARGET_NODE within the $TARGET_NAMESPACE network"
echo

echo "....................."
echo

export SEED_DATA=$(kubectl exec $TARGET_NODE -c mina --namespace $TARGET_NAMESPACE -- /bin/bash -c "curl -d '{\"query\": \"{version block(height: $HARDFORK_BLOCK) {protocolState {consensusState {stakingEpochData {seed} nextEpochData {seed}}}}}\"}' -H 'Content-Type: application/json' http://localhost:3085/graphql")
export NEXT_EPOCH_SEED=$(echo "$SEED_DATA" | jq '.data.block.protocolState.consensusState.nextEpochData.seed')
export STAKING_EPOCH_SEED=$(echo "$SEED_DATA" | jq '.data.block.protocolState.consensusState.stakingEpochData.seed')

echo
echo "....................."
echo

if [ "$NEXT_EPOCH_SEED" = "null" ];
    then
        echo "no epoch seeds could be extracted from the graphql query response"
        echo "exporting of the hard fork epoch seeds has failed!"
        echo
        exit 1
    else
        echo "the extracted next epoch seed is: $NEXT_EPOCH_SEED"
        echo
fi

if [ "$STAKING_EPOCH_SEED" = "null" ];
    then
        echo "no epoch seeds could be extracted from the graphql query response"
        echo "exporting of the hard fork epoch seeds has failed!"
        echo
        exit 1
    else
        echo "the extracted staking epoch seed is: $STAKING_EPOCH_SEED"
        echo
fi

# example error: {"errors":[{"message":"Could not find block in transition frontier with height 236474","path":["block"]}],"data":null}
# example error: OCI runtime exec failed: exec failed: container_linux.go:380: starting container process caused: exec: "curl -d '{\"query\": \"{version block(height: 7603) {protocolState {consensusState {stakingEpochData {seed} nextEpochData {seed}}}}}\"}' -H 'Content-Type: application/json' http://localhost:3085/graphql": stat curl -d '{"query": "{version block(height: 7603) {protocolState {consensusState {stakingEpochData {seed} nextEpochData {seed}}}}}"}' -H 'Content-Type: application/json' http://localhost:3085/graphql: no such file or directory: unknown

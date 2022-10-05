#!/bin/bash
set -e

TESTNET="$1"
KEYS_PREFIX="$2"

if [ -z "$CLUSTER" ]; then
  CLUSTER="$(kubectl config current-context)"
fi

# kubectl apply -f ~/o1/turbo-pickles/secrets/ && exit 0

# always relative to rootdir
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd "${SCRIPTPATH}/../"

whale_keys=${KEYS_PREFIX}keys/testnet-keys/${TESTNET}_online-whale-keyfiles
fish_keys=${KEYS_PREFIX}keys/testnet-keys/${TESTNET}_online-fish-keyfiles
seed_keys=${KEYS_PREFIX}keys/testnet-keys/${TESTNET}_seed-keyfiles

if [ ! -d $fish_keys ]; then
  echo "fish keys folder does not exist at $fish_keys"
  exit 1
fi

if [ ! -d $whale_keys ]; then
  echo "whale keys folder does not exist at $whale_keys"
  exit 1
fi

if [ ! -d $seed_keys ]; then
  echo "seed keys folder does not exist at $seed_keys"
  exit 1
fi

if [ -z "$TESTNET" ]; then
  echo 'MISSING ARGUMENT'
  exit 1
fi

function upload_keys_by_folder {
  for pubkey in $1/*.pub; do
    privkey="${pubkey%.*}" # strip pub extension
    justfilename=$(basename -- "$privkey")
    secretname=$(echo $justfilename | tr _ -)-key

    kubectl create secret generic $secretname --cluster=$CLUSTER --namespace=$TESTNET --from-file=key=${privkey} --from-file=pub=${pubkey}
  done

  for pubkey in $1/*.peerid; do
    privkey="${pubkey%.*}" # strip peerid extension
    justfilename=$(basename -- "$privkey")
    secretname=$(echo $justfilename | tr _ -)-key

    kubectl create secret generic $secretname --cluster=$CLUSTER --namespace=$TESTNET --from-file=key=${privkey} --from-file=pub=${pubkey}
  done
}

echo 'UPLOADING KEYS'

#whales
upload_keys_by_folder $whale_keys

#fish
upload_keys_by_folder $fish_keys

#seeds
upload_keys_by_folder $seed_keys

#bots
if [ -e keys/testnet-keys/bots_keyfiles/echo_service.pub ]; then
  upload_keys_by_folder ${KEYS_PREFIX}keys/testnet-keys/bots_keyfiles
else
  echo '*** NOT UPLOADING BOT KEYS (required when running with bots sidecar)'
fi

if [ -e keys/api-keys/o1-discord-api-key ]; then
  kubectl create secret generic o1-discord-api-key \
    "--cluster=$CLUSTER" \
    "--namespace=$TESTNET" \
    "--from-file=o1discord=${KEYS_PREFIX}keys/api-keys/o1-discord-api-key"
else
  echo '*** NOT UPLOADING DISCORD API KEY (required when running with bots sidecar)'
fi

if [ -e gcloud-keyfile.json ]; then
  kubectl create secret generic gcloud-keyfile --cluster=$CLUSTER --namespace=$TESTNET --from-file=keyfile=gcloud-keyfile.json
fi

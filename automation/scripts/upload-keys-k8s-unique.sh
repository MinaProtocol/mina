#!/bin/bash
# this script has an additional function to upload a unique block producer password
# by default, O(1) testsnets use a single blockc producer keypass and not one that is unique

set -e

TESTNET="$1"

if [ -z "$CLUSTER" ]; then
  CLUSTER="$(kubectl config current-context)"
fi

# kubectl apply -f ~/o1/turbo-pickles/secrets/ && exit 0

# always relative to rootdir
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd "${SCRIPTPATH}/../"

KEYS_DIR=./terraform/testnets/${TESTNET}/keys
LIBP2P_KEYS_DIR=./terraform/testnets/${TESTNET}/keys/libp2p-keys

if [ ! -d $KEYS_DIR ]; then
  echo "keys folder does not exist at $KEYS_DIR"
  exit 1
fi

if [ ! -d $PASS_DIR ]; then
  echo "bp key pass folder does not exist at $KEYS_DIR"
  exit 1
fi

if [ ! -d $LIBP2P_KEYS_DIR ]; then
  echo "libp2p keys folder does not exist at $LIBP2P_KEYS_DIR"
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
}

function upload_bp_passkeys_by_folder {
  for keypass in $1/*.txt; do
    pass="${keypass%.*}" # strip pass extension
    justfilename=$(basename -- "$pass")
    secretname=$(echo $justfilename | tr _ -)-keypass

    kubectl create secret generic $secretname --cluster=$CLUSTER --namespace=$TESTNET --from-file=keypass=${keypass}
  done
}

function upload_libp2p_keys_by_folder {
  for pubkey in $1/*.peerid; do
    privkey="${pubkey%.*}" # strip peerid extension
    justfilename=$(basename -- "$privkey")
    secretname=$(echo $justfilename | tr _ -)-key

    echo $justfilename
    echo $secretname

    kubectl create secret generic $secretname --cluster=$CLUSTER --namespace=$TESTNET --from-file=key=${privkey} --from-file=pub=${pubkey}
  done
}

echo 'UPLOADING KEYS'

# account keys
upload_keys_by_folder $KEYS_DIR

# unique block producer key passwords
upload_bp_passkeys_by_folder $KEYS_DIR

# libp2p
upload_libp2p_keys_by_folder $LIBP2P_KEYS_DIR

# #bots
# if [ -e keys/testnet-keys/bots_keyfiles/echo_service.pub ]; then
#   upload_keys_by_folder ${KEYS_PREFIX}keys/testnet-keys/bots_keyfiles
# else
#   echo '*** NOT UPLOADING BOT KEYS (required when running with bots sidecar)'
# fi

# if [ -e keys/api-keys/o1-discord-api-key ]; then
#   kubectl create secret generic o1-discord-api-key \
#     "--cluster=$CLUSTER" \
#     "--namespace=$TESTNET" \
#     "--from-file=o1discord=${KEYS_PREFIX}keys/api-keys/o1-discord-api-key"
# else
#   echo '*** NOT UPLOADING DISCORD API KEY (required when running with bots sidecar)'
# fi

CRED_FILE=./terraform/testnets/${TESTNET}/gcloud-keyfile.json

if [ -e $CRED_FILE ]; then
  kubectl create secret generic gcloud-keyfile --cluster=$CLUSTER --namespace=$TESTNET --from-file=keyfile=$CRED_FILE
fi

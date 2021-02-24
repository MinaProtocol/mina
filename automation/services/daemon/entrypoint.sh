#!/bin/bash

# Entrypoint for the Coda daemon service container
# Features: 
#   - Fetches Secrets (Wallet Keys) from AWS Secrets Manager on startup 
#       - Configured via environment variable `CODA_WALLET_KEYS`
#       -  `CODA_WALLET_KEYS=testnet/keys/echo/0 testnet/keys/grumpus/0`
#   - Starts coda daemon with those secrets
#   - Optionally runs a SNARK Worker
#   - Optionally runs a Block Producer

CLEAR='\033[0m'
RED='\033[0;31m'

function usage() {
  if [ -n "$1" ]; then
    echo -e "${RED}👉  $1${CLEAR}\n";
  fi
  echo "Usage: $0"
  echo "  --dont-fetch-secrets           If set, don't fetch secrets from AWS Secrets Manager. Default: False"
  echo "  --no-daemon                    If set, don't run the daemon. Default: False"
  echo "  --snark-worker-public-key      If set, run a SNARK worker using the public key passed as input."
  echo "  --block-producer-public-key    If set, run a Block Producer using the public key passed as input."
  echo ""
  echo "Example: $0"
  exit 1
}

while [[ "$#" -gt 0 ]]; do case $1 in
  --run-snark-worker) CODA_SNARK_KEY="$2"; shift;;
  -v|--run-block-producer) CODA_PROPOSE_KEY="$2"; shift;;
  -c|--command) COMMAND="$2"; shift;;
  --dont-fetch-secrets) NOFETCH=1; shift;;
  --no-daemon) NODAEMON=1; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

# Load CODA_WALLET_KEYS array from environment
keys=($CODA_WALLET_KEYS)
key_files=()
# For each Secrets Manager key
for key in "${keys[@]}"
do
    aws --version
    # Retrieve the secret value
    secret_json="$(aws secretsmanager get-secret-value --secret-id $key | jq '.SecretString | fromjson')"
    pk="$(echo $secret_json | jq -r .public_key)"
    sk="$(echo $secret_json | jq -r .secret_key)"

    # Write public key to a file
    echo "$pk" > "/wallet-keys/$pk.pub"
    # Write private key to a file
    echo "$sk" > "/wallet-keys/$pk"
    #Set permissions on private key
    chmod 600 "/wallet-keys/$pk"
    
    key_files+=( "/wallet-keys/$pk" )
done

# Build ROLE_COMMAND
ROLE_COMMAND=""
if [ -n "$CODA_SNARK_KEY" ];then
   ROLE_COMMAND+="-run-snark-worker $CODA_SNARK_KEY -snark-worker-fee 50";
fi

if [ -n "$CODA_PROPOSE_KEY" ];then
  ROLE_COMMAND+="-propose-public-key $CODA_PROPOSE_KEY ";
fi

if [ -n "$CODA_ARCHIVE_NODE" ];then
  ROLE_COMMAND+="-archive"
fi

echo "$ROLE_COMMAND"

# Make Config Directory
mkdir ~/coda-config

# Run Coda Daemon

# Import Wallets
set -x
for file in "${key_files[@]}"
do
  coda advanced unsafe-import -config-dir ~/coda-config -privkey-path $file
done



if [ -z "$NODAEMON" ] || [ "$NODAEMON" -eq 0 ]; then

  coda daemon -config-directory ~/coda-config $ROLE_COMMAND -client-port $DAEMON_CLIENT_PORT -rest-port $DAEMON_REST_PORT -external-port $DAEMON_EXTERNAL_PORT  -discovery-port $DAEMON_DISCOVERY_PORT -metrics-port $DAEMON_METRICS_PORT \
    -peer /dns4/peer1-$CODA_TESTNET.o1test.net/tcp/8303/p2p/12D3KooWHMmfuS9DmmK9eH4GC31arDhbtHEBQzX6PwPtQftxzwJs \
    -peer /dns4/peer2-$CODA_TESTNET.o1test.net/tcp/8303/p2p/12D3KooWAux9MAW1yAdD8gsDbYHmgVjRvdfYkpkfX7AnyGvQaRPF \
    -peer /dns4/peer3-$CODA_TESTNET.o1test.net/tcp/8303/p2p/12D3KooWCZA4pPWmDAkQf6riDQ3XMRN5k99tCsiRhBAPZCkA8re7
fi

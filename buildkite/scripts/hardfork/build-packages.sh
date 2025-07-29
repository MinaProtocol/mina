#!/bin/bash

set -eo pipefail

# shellcheck source=./buildkite/scripts/export-git-env-vars.sh
source ./buildkite/scripts/export-git-env-vars.sh

if [ -z "${CONFIG_JSON_GZ_URL+x}" ] || [ -z "${NETWORK_NAME+x}" ] || [ -z "${MINA_DEB_CODENAME+x}" ]; then
    echo "❌ Error: Required environment variables not provided:"
    [ -z "${CONFIG_JSON_GZ_URL+x}" ] && echo "  - CONFIG_JSON_GZ_URL: URL to download the network configuration JSON file 🌐"
    [ -z "${NETWORK_NAME+x}" ] && echo "  - NETWORK_NAME: Name of the network to create hardfork package for 🔗"
    [ -z "${MINA_DEB_CODENAME+x}" ] && echo "  - MINA_DEB_CODENAME: Debian codename for package building 📦"
    exit 1
fi

echo "--- Starting hardfork package generation for network: ${NETWORK_NAME} with Debian codename: ${MINA_DEB_CODENAME}"

if [ "${NETWORK_NAME}" = "mainnet" ]; then
  export MINA_BUILD_MAINNET=1
fi
./buildkite/scripts/build-artifact.sh

# Set the base network config for ./scripts/hardfork/create_runtime_config.sh
export FORKING_FROM_CONFIG_JSON="genesis_ledgers/${NETWORK_NAME}.json"
[ ! -f "${FORKING_FROM_CONFIG_JSON}" ] && echo "${NETWORK_NAME} is not a known network name; check for existing network configs in 'genesis_ledgers/'" && exit 1

echo "--- Download and extract previous network config"
curl -o config.json.gz $CONFIG_JSON_GZ_URL
gunzip config.json.gz

echo "--- Generate hardfork ledger tarballs"
mkdir hardfork_ledgers
_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --config-file config.json --genesis-dir hardfork_ledgers/ --hash-output-file hardfork_ledger_hashes.json | tee runtime_genesis_ledger.log | _build/default/src/app/logproc/logproc.exe

echo "--- Create hardfork config"
FORK_CONFIG_JSON=config.json LEDGER_HASHES_JSON=hardfork_ledger_hashes.json scripts/hardfork/create_runtime_config.sh > new_config.json

existing_files=$(aws s3 ls s3://snark-keys.o1test.net/ | awk '{print $4}')
for file in hardfork_ledgers/*; do
  filename=$(basename "$file")
  
  if echo "$existing_files" | grep -q "$filename"; then
    echo "Info: $filename already exists in the bucket, packaging it instead."
    oldhash=$(openssl dgst -r -sha3-256 "$file" | awk '{print $1}')
    aws s3 cp "s3://snark-keys.o1test.net/$filename" "$file"
    newhash=$(openssl dgst -r -sha3-256 "$file" | awk '{print $1}')
    sed -i "s/$oldhash/$newhash/g" new_config.json 
  else
    aws s3 cp --acl public-read "$file" s3://snark-keys.o1test.net/
  fi
done

echo "--- New genesis config"
head new_config.json

echo "--- Build hardfork package for Debian ${MINA_DEB_CODENAME}"
RUNTIME_CONFIG_JSON=/workdir/new_config.json LEDGER_TARBALLS="$(echo /workdir/hardfork_ledgers/*.tar.gz)" ./scripts/debian/build.sh "$@"
mkdir -p /tmp/artifacts
cp _build/mina*.deb /tmp/artifacts/.

echo "--- Git diff after build is complete:"
git diff --exit-code -- .
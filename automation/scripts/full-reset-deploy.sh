#!/bin/bash

genkeys=${1:-"generate-keys"}
deploy=${2:-"deploy"}
namespace=${3:-"pickles-nightly"}

#===================================
if [ $genkeys == "generate-keys" ]; then
  echo "preparing keys and ledger"

  rm -rf scripts/offline_whale_keys
  rm -rf scripts/offline_fish_keys
  rm -rf scripts/online_whale_keys
  rm -rf scripts/online_fish_keys
  rm -rf scripts/service-keys

  N=10

  python3 scripts/testnet-keys.py keys  generate-offline-fish-keys --count $N
  python3 scripts/testnet-keys.py keys  generate-online-fish-keys --count $N
  python3 scripts/testnet-keys.py keys  generate-offline-whale-keys --count $N
  python3 scripts/testnet-keys.py keys  generate-online-whale-keys --count $N

  python3 scripts/testnet-keys.py ledger generate-ledger --num-whale-accounts $N --num-fish-accounts $N
fi

# ===================================
if [ $deploy == "deploy" ]; then
  echo "deploying network"
  ./scripts/auto-deploy.sh $namespace
fi

# ===================================
echo "getting version"

version=$(./scripts/get_version.sh $namespace)
while [ -z "$version" ]; do
  echo "retrying..."
  version=$(./scripts/get_version.sh $namespace)
  sleep 5;
done

echo "version: $version"

# ===================================



#! /bin/bash

while [ $# -gt 0 ]; do
  case "$1" in
    --testnet=*)
      TESTNET="${1#*=}"
      ;;
    --artifact-path=*)
      ARTIFACT_PATH="${1#*=}"
      ;;
  esac
  shift
done

# if override not provided, default to testnets DIR
if [[ ! $ARTIFACT_PATH ]]; then
  ARTIFACT_PATH="terraform/testnets/${TESTNET}"
fi

addrs=
for f in ${ARTIFACT_PATH}/keys/libp2p-keys/seed-*; do
  node=$(basename $f)
  peerid=$(cat $f)
  idx=$(echo "$f" | awk -F- '{print $NF}')

  libp2p_addr="/dns4/"$node"."$TESTNET".o1test.net/tcp/$((10000 + idx - 1))/p2p/$peerid"
  addrs=$addrs$libp2p_addr"\n"
done

echo -e "$addrs" > $ARTIFACT_PATH/"$TESTNET"_seeds.txt

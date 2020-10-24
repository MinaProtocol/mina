#!/bin/bash

whales=1
fish=1
nodes=1
transactions=false
reset=false

help=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -w|--whales) whales="$2"; shift ;;
        -f|--fish) fish="$2"; shift ;;
        -n|--nodes) nodes="$2"; shift ;;
        -t|--transactions) transactions=truee; shift ;;
        -r|--reset) reset=true; shift;;
        -h|--help) help=true; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if $help; then
  echo "-w|--whales #"
  echo "-f|--fish #"
  echo "-n|--nodes #"
  echo "-t|--transactions"
  echo "-r|--reset"
  echo "-h|--help"
  exit
fi

if $transactions; then
  echo "automated transactions in addition to coinbase not supported yet"
  exit
fi

# ================================================

echo "Starting network with:"
echo -e "\t$whales whales"
echo -e "\t$fish fish"
echo -e "\t$nodes non block-producing nodes"
echo -e "\tautomated transactions: $transactions"

# ================================================

# kill background process when script closes
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

ledgerfolder="/tmp/mina-local-network-$whales-$fish-$nodes"

if $reset; then
  rm -rf "$ledgerfolder"
fi

if [ ! -d "$ledgerfolder" ]; then
  echo "making ledger"
  
  mkdir $ledgerfolder

  S=./coda-automation/scripts

  rm -rf $ledgerfolder/offline_whale_keys
  rm -rf $ledgerfolder/offline_fish_keys
  rm -rf $ledgerfolder/online_whale_keys
  rm -rf $ledgerfolder/online_fish_keys
  rm -rf $ledgerfolder/service-keys

  python3 $S/testnet-keys.py keys generate-offline-fish-keys --count $fish --output-dir $ledgerfolder/offline_fish_keys
  python3 $S/testnet-keys.py keys generate-online-fish-keys --count $fish --output-dir $ledgerfolder/online_fish_keys
  python3 $S/testnet-keys.py keys generate-offline-whale-keys --count $whales --output-dir $ledgerfolder/offline_whale_keys
  python3 $S/testnet-keys.py keys generate-online-whale-keys --count $whales --output-dir $ledgerfolder/online_whale_keys

  python3 $S/testnet-keys.py ledger generate-ledger --num-whale-accounts $whales --num-fish-accounts $fish \
          --offline-whale-accounts-directory $ledgerfolder/offline_whale_keys  \
          --offline-fish-accounts-directory $ledgerfolder/offline_fish_keys \
          --online-whale-accounts-directory $ledgerfolder/online_whale_keys  \
          --online-fish-accounts-directory $ledgerfolder/online_fish_keys

  cp $S/genesis_ledger.json $ledgerfolder/genesis_ledger.json
fi

echo "exit"

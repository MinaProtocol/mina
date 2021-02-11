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
        -t|--transactions) transactions=true ;;
        -r|--reset) reset=true ;;
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
  if [ "$fish" -eq "0" ]; then
    echo "sending transactions require at least one fish"
    exit
  fi
fi

# kill background process when script closes
trap "killall background" EXIT

# ================================================

echo "Starting network with:"
echo -e "\t1 seed"
echo -e "\t$whales whales"
echo -e "\t$fish fish"
echo -e "\t$nodes non block-producing nodes"
echo -e "\tsending transactions: $transactions"

# ================================================
# Create genesis ledger

ledgerfolder="/tmp/mina-local-network-$whales-$fish-$nodes"

if $reset; then
  rm -rf "$ledgerfolder"
fi

if [ ! -d "$ledgerfolder" ]; then
  echo "making ledger"
  
  mkdir $ledgerfolder

  S=./automation/scripts

  rm -rf $ledgerfolder/offline_whale_keys
  rm -rf $ledgerfolder/offline_fish_keys
  rm -rf $ledgerfolder/online_whale_keys
  rm -rf $ledgerfolder/online_fish_keys
  rm -rf $ledgerfolder/service-keys

  python3 $S/testnet-keys.py keys generate-offline-fish-keys --count $fish --output-dir $ledgerfolder/offline_fish_keys
  python3 $S/testnet-keys.py keys generate-online-fish-keys --count $fish --output-dir $ledgerfolder/online_fish_keys
  python3 $S/testnet-keys.py keys generate-offline-whale-keys --count $whales --output-dir $ledgerfolder/offline_whale_keys
  python3 $S/testnet-keys.py keys generate-online-whale-keys --count $whales --output-dir $ledgerfolder/online_whale_keys

  if [ "$(uname)" != "Darwin" ]; then
    file=$(ls $ledgerfolder/offline_fish_keys/ | head -n 1)
    owner=$(stat -c "%U" $ledgerfolder/offline_fish_keys/$file)

    if [ "$file" != "$USER" ]; then
      sudo chown -R $USER $ledgerfolder/offline_fish_keys
      sudo chown -R $USER $ledgerfolder/online_fish_keys
      sudo chown -R $USER $ledgerfolder/offline_whale_keys
      sudo chown -R $USER $ledgerfolder/online_whale_keys
    fi
  fi

  chmod -R 0700 $ledgerfolder/offline_fish_keys
  chmod -R 0700 $ledgerfolder/online_fish_keys
  chmod -R 0700 $ledgerfolder/offline_whale_keys
  chmod -R 0700 $ledgerfolder/online_whale_keys

  python3 $S/testnet-keys.py ledger generate-ledger --num-whale-accounts $whales --num-fish-accounts $fish \
          --offline-whale-accounts-directory $ledgerfolder/offline_whale_keys  \
          --offline-fish-accounts-directory $ledgerfolder/offline_fish_keys \
          --online-whale-accounts-directory $ledgerfolder/online_whale_keys  \
          --online-fish-accounts-directory $ledgerfolder/online_fish_keys

  cp $S/genesis_ledger.json $ledgerfolder/genesis_ledger.json
fi

echo "$ledgerfolder/genesis_ledger.json"

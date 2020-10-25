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

# kill background process when script closes
trap "killall background" EXIT

# ================================================

echo "Starting network with:"
echo -e "\t1 seed"
echo -e "\t$whales whales"
echo -e "\t$fish fish"
echo -e "\t$nodes non block-producing nodes"
echo -e "\tautomated transactions: $transactions"

# ================================================
# Create genesis ledger

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

# ================================================
# Update Timestamp

python - <<END
import json
import datetime

d = datetime.datetime.utcnow()
d = d.isoformat("T") + "Z"

with open("$ledgerfolder/genesis_ledger.json") as f:
  ledger = json.load(f)

data = {
  "genesis": {
    "genesis_state_timestamp": d,
  },
  "ledger": ledger
}

with open("$ledgerfolder/daemon.json", 'w') as outfile:
    json.dump(data, outfile)
END

daemon=$ledgerfolder/daemon.json

# ================================================
# Launch nodes

CODA=_build/default/src/app/cli/src/coda.exe
LOGPROC=_build/default/src/app/logproc/logproc.exe


nodesfolder=$ledgerfolder/nodes

rm -rf $nodesfolder
mkdir -p $nodesfolder

# ----------

mkdir $nodesfolder/seed

$CODA daemon -seed -client-port 3000 -rest-port 3001 -external-port 3002 -config-directory $nodesfolder/seed -config-file $daemon -generate-genesis-proof true -discovery-keypair CAESQNf7ldToowe604aFXdZ76GqW/XVlDmnXmBT+otorvIekBmBaDWu/6ZwYkZzqfr+3IrEh6FLbHQ3VSmubV9I9Kpc=,CAESIAZgWg1rv+mcGJGc6n6/tyKxIehS2x0N1Uprm1fSPSqX,12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr -log-json -log-level Trace &> $nodesfolder/seed/log.txt &
seed_pid=$!

sleep 5

# ----------

whale_start_port=4000
for i in $(seq 1 $whales); do
  folder=$nodesfolder/whale_$i
  keyfile=$ledgerfolder/online_whale_keys/online_whale_account_$i
  logfile=$folder/log.txt
  mkdir $folder
  client_port=$(echo $whale_start_port + 0 + $i*5 | bc)
  rest_port=$(echo $whale_start_port + 1 + $i*5 | bc)
  ext_port=$(echo $whale_start_port + 2 + $i*5 | bc)

  CODA_PRIVKEY_PASS="naughty blue worm" $CODA daemon -peer "/ip4/127.0.0.1/tcp/3002/p2p/12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr" -client-port $client_port -rest-port $rest_port -external-port $ext_port -config-directory $folder -config-file $daemon -generate-genesis-proof true -block-producer-key $keyfile -log-json -run-snark-worker B62qp4UturELw4MmhAZhor8rwzaH1BBAivRnvdp1Yhkq6odhhFiT8uC -work-selection seq -log-level Trace &> $logfile &
  whale_pids[${i}]=$!
  whale_logfiles[${i}]=$logfile
  whale_clientport[${i}]=$client_port
done

# ----------

fish_start_port=5000
for i in $(seq 1 $fish); do
  folder=$nodesfolder/fish_$i
  keyfile=$ledgerfolder/online_fish_keys/online_fish_account_$i
  logfile=$folder/log.txt
  mkdir $folder
  client_port=$(echo $fish_start_port + 0 + $i*5 | bc)
  rest_port=$(echo $fish_start_port + 1 + $i*5 | bc)
  ext_port=$(echo $fish_start_port + 2 + $i*5 | bc)

  CODA_PRIVKEY_PASS="naughty blue worm" $CODA daemon -peer "/ip4/127.0.0.1/tcp/3002/p2p/12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr" -client-port $client_port -rest-port $rest_port -external-port $ext_port -config-directory $folder -config-file $daemon -generate-genesis-proof true -block-producer-key $keyfile -log-json -run-snark-worker B62qp4UturELw4MmhAZhor8rwzaH1BBAivRnvdp1Yhkq6odhhFiT8uC -work-selection seq -log-level Trace &> $logfile &
  fish_pids[${i}]=$!
  fish_logfiles[${i}]=$logfile
  fish_clientport[${i}]=$client_port
done

# ----------

node_start_port=6000
for i in $(seq 1 $nodes); do
  folder=$nodesfolder/node_$i
  keyfile=$ledgerfolder/online_node_keys/online_node_account_$i
  logfile=$folder/log.txt
  mkdir $folder
  client_port=$(echo $node_start_port + 0 + $i*5 | bc)
  rest_port=$(echo $node_start_port + 1 + $i*5 | bc)
  ext_port=$(echo $node_start_port + 2 + $i*5 | bc)

  CODA_PRIVKEY_PASS="naughty blue worm" $CODA daemon -peer "/ip4/127.0.0.1/tcp/3002/p2p/12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr" -client-port $client_port -rest-port $rest_port -external-port $ext_port -config-directory $folder -config-file $daemon -generate-genesis-proof true -log-json -log-level Trace &> $logfile &
  node_pids[${i}]=$!
  node_logfiles[${i}]=$logfile
  node_clientport[${i}]=$client_port
done

# ================================================


echo "Node information:"

echo -e "\tseed"
echo -e "\t\t1"
echo -e "\t\t  pid $seed_pid"
echo -e "\t\t  status: $CODA client status -daemon-port 3000"
echo -e "\t\t  logs: cat $nodesfolder/seed/log.txt | $LOGPROC"

echo -e "\twhales"
for i in $(seq 1 $whales); do
  echo -e "\t\t$i"
  echo -e "\t\t  pid ${whale_pids[${i}]}"
  echo -e "\t\t  status: $CODA client status -daemon-port ${whale_clientport[${i}]}"
  echo -e "\t\t  logs: cat ${whale_logfiles[${i}]} | $LOGPROC"
done

echo -e "\tfish"
for i in $(seq 1 $fish); do
  echo -e "\t\t$i"
  echo -e "\t\t  pid ${fish_pids[${i}]}"
  echo -e "\t\t  status: $CODA client status -daemon-port ${fish_clientport[${i}]}"
  echo -e "\t\t  logs: cat ${fish_logfiles[${i}]} | $LOGPROC"
done

echo -e "\tnodes"
for i in $(seq 1 $nodes); do
  echo -e "\t\t$i"
  echo -e "\t\t  pid ${node_pids[${i}]}"
  echo -e "\t\t  status: $CODA client status -daemon-port ${node_clientport[${i}]}"
  echo -e "\t\t  logs: cat ${node_logfiles[${i}]} | $LOGPROC"
done

# ================================================
# Wait for nodes

wait

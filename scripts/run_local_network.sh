#!/bin/bash

# exit script when commands fail
set -e
# kill background process when script closes
trap "killall background" EXIT

# ================================================
# Constants

MINA=_build/default/src/app/cli/src/mina.exe
ARCHIVE=_build/default/src/app/archive/archive.exe
LOGPROC=_build/default/src/app/logproc/logproc.exe

export MINA_PRIVKEY_PASS='naughty blue worm'
SEED_PEER_KEY="CAESQNf7ldToowe604aFXdZ76GqW/XVlDmnXmBT+otorvIekBmBaDWu/6ZwYkZzqfr+3IrEh6FLbHQ3VSmubV9I9Kpc=,CAESIAZgWg1rv+mcGJGc6n6/tyKxIehS2x0N1Uprm1fSPSqX,12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"
SEED_PEER_ID="/ip4/127.0.0.1/tcp/3002/p2p/12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"

SNARK_WORKER_FEE=0.01

TRANSACTION_FREQUENCY=5

WHALE_START_PORT=4000
FISH_START_PORT=5000
NODE_START_PORT=6000

ARCHIVE_PORT=3086

# ================================================
# Inputs (set to default values)

whales=1
fish=1
nodes=1
transactions=false
reset=false

# ================================================
# Globals (assigned during execution of script)

ledgerfolder=""
snark_worker_pubkey=""
nodesfolder=""
config=""
seed_pid=""
whale_pids=()
fish_pids=()
node_pids=()

# ================================================
# Helper functions

help() {
  echo "-w|--whales #"
  echo "-f|--fish #"
  echo "-n|--nodes #"
  echo "-t|--transactions"
  echo "-r|--reset"
  echo "-h|--help"
  exit
}

clean-dir() {
  rm -rf $1
  mkdir -p $1
}

generate-keypair() {
  $MINA advanced generate-keypair -privkey-path $1
}

# Execute a daemon, exposing all 5 ports in
# sequence starting with provided base port.
exec-daemon() {
  base_port=$1
  shift
  client_port=$base_port
  rest_port=$(($base_port+1))
  external_port=$(($base_port+2))
  daemon_metrics_port=$(($base_port+3))
  libp2p_metrics_port=$(($base_port+4))
  echo $MINA daemon \
    -client-port $client_port \
    -rest-port $rest_port \
    -external-port $external_port \
    -metrics-port $daemon_metrics_port \
    -libp2p-metrics-port $libp2p_metrics_port \
    -config-file $config \
    -generate-genesis-proof true \
    -log-json \
    -log-level Trace \
    $@
  exec $MINA daemon \
    -client-port $client_port \
    -rest-port $rest_port \
    -external-port $external_port \
    -metrics-port $daemon_metrics_port \
    -libp2p-metrics-port $libp2p_metrics_port \
    -config-file $config \
    -generate-genesis-proof true \
    -log-json \
    -log-level Trace \
    $@
}

exec-archive() {
  echo $ARCHIVE run \
       -postgres-uri postgres://postgres@localhost:5432/archive_local_network \
       -config-file $config \
       -server-port $ARCHIVE_PORT
  exec $ARCHIVE run \
       -postgres-uri postgres://postgres@localhost:5432/archive_local_network \
       -config-file $config \
       -server-port $ARCHIVE_PORT
}

# Spawn a node in the background.
# Configures node directory and logs.
spawn-node() {
  folder=$1
  shift
  exec-daemon $@ -config-directory $folder &> $folder/log.txt &
}

spawn-archive() {
  folder=$1
  exec-archive &> $folder/log-archive.txt &
}

# ================================================
# PARSE INPUTS FROM ARGUMENTS

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -w|--whales) whales="$2"; shift ;;
        -f|--fish) fish="$2"; shift ;;
        -n|--nodes) nodes="$2"; shift ;;
        -t|--transactions) transactions=true ;;
        -r|--reset) reset=true ;;
        -h|--help) help ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if $transactions; then
  if [ "$fish" -eq "0" ]; then
    echo "sending transactions require at least one fish"
    exit
  fi
fi

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

  clean-dir $ledgerfolder/offline_whale_keys
  clean-dir $ledgerfolder/offline_fish_keys
  clean-dir $ledgerfolder/online_whale_keys
  clean-dir $ledgerfolder/online_fish_keys
  clean-dir $ledgerfolder/service-keys

  generate-keypair $ledgerfolder/snark_worker_keys/snark_worker_account
  for i in $(seq 1 $fish); do
    generate-keypair $ledgerfolder/offline_fish_keys/offline_fish_account_$i
    generate-keypair $ledgerfolder/online_fish_keys/online_fish_account_$i
  done
  for i in $(seq 1 $whales); do
    generate-keypair $ledgerfolder/offline_whale_keys/offline_whale_account_$i
    generate-keypair $ledgerfolder/online_whale_keys/online_whale_account_$i
  done

  if [ "$(uname)" != "Darwin" ] && [ $fish -gt 0 ]; then
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

  python3 scripts/generate-local-network-ledger.py \
    --num-whale-accounts $whales \
    --num-fish-accounts $fish \
    --offline-whale-accounts-directory $ledgerfolder/offline_whale_keys  \
    --offline-fish-accounts-directory $ledgerfolder/offline_fish_keys \
    --online-whale-accounts-directory $ledgerfolder/online_whale_keys \
    --online-fish-accounts-directory $ledgerfolder/online_fish_keys

  cp scripts/genesis_ledger.json $ledgerfolder/genesis_ledger.json
fi

snark_worker_pubkey=$(cat $ledgerfolder/snark_worker_keys/snark_worker_account.pub)

# ================================================
# Update Timestamp

config=$ledgerfolder/daemon.json
jq "{genesis: {genesis_state_timestamp:\"$(date -u +"%Y-%m-%dT%H:%M:%S.%6NZ")\"}, ledger:.}" \
  < $ledgerfolder/genesis_ledger.json \
  > $config

# ================================================
# Launch nodes

nodesfolder=$ledgerfolder/nodes
clean-dir $nodesfolder

# ----------

mkdir $nodesfolder/seed

spawn-archive $nodesfolder/seed
spawn-node $nodesfolder/seed 3000 -seed -discovery-keypair $SEED_PEER_KEY -archive-address $ARCHIVE_PORT
seed_pid=$!

echo 'waiting for seed to go up...'

until $MINA client status -daemon-port 3000 &> /dev/null
do
  sleep 1
done

# ----------

snark_worker_flags="-snark-worker-fee $SNARK_WORKER_FEE -run-snark-worker $snark_worker_pubkey -work-selection seq"

for i in $(seq 1 $whales); do
  folder=$nodesfolder/whale_$i
  keyfile=$ledgerfolder/online_whale_keys/online_whale_account_$i
  mkdir $folder
  spawn-node $folder $(($WHALE_START_PORT+($i-1)*5)) -peer $SEED_PEER_ID -block-producer-key $keyfile $snark_worker_flags -archive-address $ARCHIVE_PORT
  whale_pids[${i}]=$!
done

# ----------

for i in $(seq 1 $fish); do
  folder=$nodesfolder/fish_$i
  keyfile=$ledgerfolder/online_fish_keys/online_fish_account_$i
  mkdir $folder
  spawn-node $folder $(($FISH_START_PORT+($i-1)*5)) -peer $SEED_PEER_ID -block-producer-key $keyfile $snark_worker_flags -archive-address $ARCHIVE_PORT
  fish_pids[${i}]=$!
done

# ----------

for i in $(seq 1 $nodes); do
  folder=$nodesfolder/node_$i
  mkdir $folder
  spawn-node $folder $(($NODE_START_PORT+($i-1)*5)) -peer $SEED_PEER_ID -archive-address $ARCHIVE_PORT
  node_pids[${i}]=$!
done

# ================================================

echo "Node information:"

echo -e "\tseed"
echo -e "\t\t1"
echo -e "\t\t  pid $seed_pid"
echo -e "\t\t  status: $MINA client status -daemon-port 3000"
echo -e "\t\t  logs: cat $nodesfolder/seed/log.txt | $LOGPROC"

echo -e "\twhales"
for i in $(seq 1 $whales); do
  echo -e "\t\t$i"
  echo -e "\t\t  pid ${whale_pids[${i}]}"
  echo -e "\t\t  status: $MINA client status -daemon-port $(($WHALE_START_PORT+($i-1)*5))"
  echo -e "\t\t  logs: cat $nodesfolder/whale_$i/log.txt | $LOGPROC"
done

echo -e "\tfish"
for i in $(seq 1 $fish); do
  echo -e "\t\t$i"
  echo -e "\t\t  pid ${fish_pids[${i}]}"
  echo -e "\t\t  status: $MINA client status -daemon-port $(($FISH_START_PORT+($i-1)*5))"
  echo -e "\t\t  logs: cat $nodesfolder/fish_$i/log.txt | $LOGPROC"
done

echo -e "\tnodes"
for i in $(seq 1 $nodes); do
  echo -e "\t\t$i"
  echo -e "\t\t  pid ${node_pids[${i}]}"
  echo -e "\t\t  status: $MINA client status -daemon-port $(($NODE_START_PORT+($i-1)*5))"
  echo -e "\t\t  logs: cat $nodesfolder/node_$i/log.txt | $LOGPROC"
done

# ================================================
# Start sending transactions

if $transactions; then
  folder=$nodesfolder/fish_1
  keyfile=$ledgerfolder/online_fish_keys/online_fish_account_1
  pubkey=$(cat $ledgerfolder/online_fish_keys/online_fish_account_1.pub)
  rest_server="http://127.0.0.1:5001/graphql"

  echo "waiting for node to be up to start sending transactions..."

  until $MINA client status -daemon-port 5000 &> /dev/null
  do
    sleep 1
  done

  echo "starting to send transactions every $transaction_frequency seconds"

  set +e

  $MINA account import -rest-server $rest_server -privkey-path $keyfile
  $MINA account unlock -rest-server $rest_server -public-key $pubkey

  sleep $TRANSACTION_FREQUENCY
  $MINA client send-payment -rest-server $rest_server -amount 1 -nonce 0 -receiver $pubkey -sender $pubkey

  while true; do
    sleep $TRANSACTION_FREQUENCY
    $MINA client send-payment -rest-server $rest_server -amount 1 -receiver $pubkey -sender $pubkey
  done

  set -e
fi

# ================================================
# Wait for nodes

wait

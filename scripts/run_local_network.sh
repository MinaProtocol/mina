#!/usr/bin/env bash
# set -x

# exit script when commands fail
set -e
# kill background process when script closes
trap "killall background" EXIT

# ================================================
# Constants

MINA=_build/default/src/app/cli/src/mina.exe
LOGPROC=_build/default/src/app/logproc/logproc.exe

export MINA_PRIVKEY_PASS='naughty blue worm'
SEED_PEER_KEY="CAESQNf7ldToowe604aFXdZ76GqW/XVlDmnXmBT+otorvIekBmBaDWu/6ZwYkZzqfr+3IrEh6FLbHQ3VSmubV9I9Kpc=,CAESIAZgWg1rv+mcGJGc6n6/tyKxIehS2x0N1Uprm1fSPSqX,12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"
SEED_PEER_ID="/ip4/127.0.0.1/tcp/3002/p2p/12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"

SNARK_WORKER_FEE=0.01

TRANSACTION_FREQUENCY=5

SEED_START_PORT=3000
WHALE_START_PORT=4000
FISH_START_PORT=5000
NODE_START_PORT=6000

# ================================================
# Inputs (set to default values)

whales=1
fish=1
nodes=1
log_level="Trace"
file_log_level=$log_level
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
  echo "-sp|--seed-start-port #"
  echo "-wp|--whale-start-port #"
  echo "-fp|--fish-start-port #"
  echo "-np|--node-start-port #"
  echo "-ll|--log-level <Spam | Trace | Debug | Info | Warn | Error | Faulty_peer | Fatal>"
  echo "-fll|--file-log-level <Same as above values>"
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
# sequence starting with provided bas port.
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
    -log-level $log_level \
    -file-log-level $file_log_level \
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
    -log-level $log_level \
    -file-log-level $file_log_level \
    $@
}

# Spawn a node in the background.
# Configures node directory and logs.
spawn-node() {
  folder=$1
  shift
  exec-daemon $@ -config-directory $folder &> $folder/log.txt &
}

# ================================================
# PARSE INPUTS FROM ARGUMENTS

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -w|--whales) whales="$2"; shift ;;
        -f|--fish) fish="$2"; shift ;;
        -n|--nodes) nodes="$2"; shift ;;
        -sp|--seed-start-port) SEED_START_PORT="$2"; shift ;;
        -wp|--whale-start-port) WHALE_START_PORT="$2"; shift ;;
        -fp|--fish-start-port) FISH_START_PORT="$2"; shift ;;
        -np|--node-start-port) NODE_START_PORT="$2"; shift ;;
        -ll|--log-level) log_level="$2"; shift ;;
        -fll|--file-log-level) file_log_level="$2"; shift ;;
        -t|--transactions) transactions=true ;;
        -r|--reset) reset=true ;;
        -h|--help) help ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if $transactions; then
  if [ "$fish" -eq "0" ]; then
    echo "Sending transactions require at least one fish"
    exit
  fi
fi

echo "Starting network with:"
echo -e "\t1 seed"
echo -e "\t$whales whales"
echo -e "\t$fish fish"
echo -e "\t$nodes non block-producing nodes"
echo -e "\tSending transactions: $transactions"

# ================================================
# Create genesis ledger

ledgerfolder="${HOME}/.mina-network/mina-local-network-$whales-$fish-$nodes"

if $reset; then
  rm -rf "$ledgerfolder"
fi

if [ ! -d "$ledgerfolder" ]; then
  printf "\n"
  echo "Making ledger"
  
  mkdir -p $ledgerfolder

  clean-dir $ledgerfolder/offline_whale_keys
  clean-dir $ledgerfolder/offline_fish_keys
  clean-dir $ledgerfolder/online_whale_keys
  clean-dir $ledgerfolder/online_fish_keys
  clean-dir $ledgerfolder/service-keys

  generate-keypair $ledgerfolder/snark_worker_keys/snark_worker_account
  for ((i = 0; i < $fish; i++)); do
    generate-keypair $ledgerfolder/offline_fish_keys/offline_fish_account_$i
    generate-keypair $ledgerfolder/online_fish_keys/online_fish_account_$i
  done
  for ((i = 0; i < $whales; i++)); do
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
jq "{genesis: {genesis_state_timestamp:\"$(date +"%Y-%m-%dT%H:%M:%S%z")\"}, ledger:.}" \
  < $ledgerfolder/genesis_ledger.json \
  > $config

# ================================================
# Launch nodes

nodesfolder=$ledgerfolder/nodes
clean-dir $nodesfolder

# ----------

mkdir -p $nodesfolder/seed

spawn-node $nodesfolder/seed ${SEED_START_PORT} -seed -discovery-keypair $SEED_PEER_KEY
seed_pid=$!

printf "\n"
echo 'Waiting for seed to go up...'

until $MINA client status -daemon-port ${SEED_START_PORT} &> /dev/null
do
  sleep 1
done

# ----------

snark_worker_flags="-snark-worker-fee $SNARK_WORKER_FEE -run-snark-worker $snark_worker_pubkey -work-selection seq"

for ((i = 0; i < $whales; i++)); do
  folder=$nodesfolder/whale_$i
  keyfile=$ledgerfolder/online_whale_keys/online_whale_account_$i
  mkdir $folder
  spawn-node $folder $(($WHALE_START_PORT+($i * 5))) -peer $SEED_PEER_ID -block-producer-key $keyfile $snark_worker_flags
  whale_pids[${i}]=$!
done

# ----------

for ((i = 0; i < $fish; i++)); do
  folder=$nodesfolder/fish_$i
  keyfile=$ledgerfolder/online_fish_keys/online_fish_account_$i
  mkdir $folder
  spawn-node $folder $(($FISH_START_PORT+($i * 5))) -peer $SEED_PEER_ID -block-producer-key $keyfile $snark_worker_flags
  fish_pids[${i}]=$!
done

# ----------

for ((i = 0; i < $nodes; i++)); do
  folder=$nodesfolder/node_$i
  mkdir $folder
  spawn-node $folder $(($NODE_START_PORT+($i * 5))) -peer $SEED_PEER_ID
  node_pids[${i}]=$!
done

# ================================================

printf "\n"
echo "Network participants information:"

echo -e "\tSeed"
echo -e "\t\tInstance #0"
echo -e "\t\t  pid $seed_pid"
echo -e "\t\t  status: $MINA client status -daemon-port ${SEED_START_PORT}"
echo -e "\t\t  logs: cat $nodesfolder/seed/log.txt | $LOGPROC"

if [ "$whales" -gt "0" ]; then
  echo -e "\tWhales"
  for ((i = 0; i < $whales; i++)); do
    echo -e "\t\tInstance #$i"
    echo -e "\t\t  pid ${whale_pids[${i}]}"
    echo -e "\t\t  status: $MINA client status -daemon-port $(($WHALE_START_PORT+($i * 5)))"
    echo -e "\t\t  logs: cat $nodesfolder/whale_$i/log.txt | $LOGPROC"
  done
fi

if [ "$fish" -gt "0" ]; then
  echo -e "\tFish"
  for ((i = 0; i < $fish; i++)); do
    echo -e "\t\tInstance #$i"
    echo -e "\t\t  pid ${fish_pids[${i}]}"
    echo -e "\t\t  status: $MINA client status -daemon-port $(($FISH_START_PORT+($i * 5)))"
    echo -e "\t\t  logs: cat $nodesfolder/fish_$i/log.txt | $LOGPROC"
  done
fi

if [ "$nodes" -gt "0" ]; then
  echo -e "\tNon block-producing nodes"
  for ((i = 0; i < $nodes; i++)); do
    echo -e "\t\tInstance #$i"
    echo -e "\t\t  pid ${node_pids[${i}]}"
    echo -e "\t\t  status: $MINA client status -daemon-port $(($NODE_START_PORT+($i * 5)))"
    echo -e "\t\t  logs: cat $nodesfolder/node_$i/log.txt | $LOGPROC"
  done
fi

# ================================================
# Start sending transactions

if $transactions; then
  folder=$nodesfolder/fish_1
  keyfile=$ledgerfolder/online_fish_keys/online_fish_account_1
  pubkey=$(cat $ledgerfolder/online_fish_keys/online_fish_account_1.pub)
  rest_server="http://127.0.0.1:5001/graphql"

  printf "\n"
  echo "Waiting for node to be up to start sending transactions..."

  until $MINA client status -daemon-port 5000 &> /dev/null
  do
    sleep 1
  done

  echo "Starting to send transactions every $transaction_frequency seconds"

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

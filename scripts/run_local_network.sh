#!/usr/bin/env bash
# set -x

# exit script when commands fail
set -e
# kill background process when script closes
trap "killall background" EXIT

# ================================================
# Constants

MINA_EXE=_build/default/src/app/cli/src/mina.exe
ARCHIVE_EXE=_build/default/src/app/archive/archive.exe
LOGPROC_EXE=_build/default/src/app/logproc/logproc.exe

export MINA_PRIVKEY_PASS='naughty blue worm'
SEED_PEER_KEY="CAESQNf7ldToowe604aFXdZ76GqW/XVlDmnXmBT+otorvIekBmBaDWu/6ZwYkZzqfr+3IrEh6FLbHQ3VSmubV9I9Kpc=,CAESIAZgWg1rv+mcGJGc6n6/tyKxIehS2x0N1Uprm1fSPSqX,12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"

SNARK_WORKER_FEE=0.01

TRANSACTION_FREQUENCY=5

SEED_START_PORT=3000
ARCHIVE_START_PORT=3086
WHALE_START_PORT=4000
FISH_START_PORT=5000
NODE_START_PORT=6000

PG_HOST="localhost"
PG_PORT="5432"
PG_USER="${USER}"
PG_PASSWD=""
PG_DB="archive"

ARCHIVE_ADDRESS_CLI_ARG=""

# ================================================
# Inputs (set to default values)

whales=1
fish=1
nodes=1
archive=false
log_level="Trace"
file_log_level=$log_level
transactions=false
reset=false
update_genesis_timestamp=false

# ================================================
# Globals (assigned during execution of script)

ledgerfolder=""
snark_worker_pubkey=""
nodesfolder=""
config=""
seed_pid=""
archive_pid=""
whale_pids=()
fish_pids=()
node_pids=()

# ================================================
# Helper functions

help() {
  echo "-w|--whales #"
  echo "-f|--fish #"
  echo "-n|--nodes #"
  echo "-a|--archive"
  echo "-sp|--seed-start-port #"
  echo "-wp|--whale-start-port #"
  echo "-fp|--fish-start-port #"
  echo "-np|--node-start-port #"
  echo "-ap|--archive-start-port #"
  echo "-ll|--log-level <Spam | Trace | Debug | Info | Warn | Error | Faulty_peer | Fatal>"
  echo "-fll|--file-log-level <Same as above values>"
  echo "-ph|--pg-host #"
  echo "-pp|--pg-port #"
  echo "-pu|--pg-user #"
  echo "-ppw|--pg-passwd #"
  echo "-pd|--pg-db #"
  echo "-t|--transactions"
  echo "-r|--reset"
  echo "-u|--update-genesis-timestamp"
  echo "-h|--help"
  exit
}

clean-dir() {
  rm -rf $1
  mkdir -p $1
}

generate-keypair() {
  $MINA_EXE advanced generate-keypair -privkey-path $1
}

# Executes the Mina Daemon, exposing all 5 ports in
# sequence starting with provided bas port.
exec-daemon() {
  base_port=$1
  shift
  client_port=$base_port
  rest_port=$(($base_port + 1))
  external_port=$(($base_port + 2))
  daemon_metrics_port=$(($base_port + 3))
  libp2p_metrics_port=$(($base_port + 4))
  echo $MINA_EXE daemon \
    -client-port $client_port \
    -rest-port $rest_port \
    -external-port $external_port \
    -metrics-port $daemon_metrics_port \
    -libp2p-metrics-port $libp2p_metrics_port \
    -config-file $config \
    -log-json \
    -log-level $log_level \
    -file-log-level $file_log_level \
    $@
  exec $MINA_EXE daemon \
    -client-port $client_port \
    -rest-port $rest_port \
    -external-port $external_port \
    -metrics-port $daemon_metrics_port \
    -libp2p-metrics-port $libp2p_metrics_port \
    -config-file $config \
    -log-json \
    -log-level $log_level \
    -file-log-level $file_log_level \
    $@
}

# Executes the Archive node
exec-archive-node() {
  echo $ARCHIVE_EXE run \
    --config-file ${config} \
    --log-level ${log_level} \
    --postgres-uri postgresql://${PG_USER}:${PG_PASSWD}@${PG_HOST}:${PG_PORT}/${PG_DB} \
    --server-port ${ARCHIVE_START_PORT} \
    $@
  exec $ARCHIVE_EXE run \
    --config-file ${config} \
    --log-level ${log_level} \
    --postgres-uri postgresql://${PG_USER}:${PG_PASSWD}@${PG_HOST}:${PG_PORT}/${PG_DB} \
    --server-port ${ARCHIVE_START_PORT} \
    $@
}

# Spawns the Node in background.
# Configures node directory and logs.
spawn-node() {
  folder=$1
  shift
  exec-daemon $@ -config-directory $folder &>$folder/log.txt &
}

# Spawns the Archive Node in background.
spawn-archive-node() {
  folder=$1
  shift
  exec-archive-node $@ &>$folder/log.txt &
}

# ================================================
# PARSE INPUTS FROM ARGUMENTS

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -w | --whales)
    whales="$2"
    shift
    ;;
  -f | --fish)
    fish="$2"
    shift
    ;;
  -n | --nodes)
    nodes="$2"
    shift
    ;;
  -a | --archive) archive=true ;;
  -sp | --seed-start-port)
    SEED_START_PORT="$2"
    shift
    ;;
  -wp | --whale-start-port)
    WHALE_START_PORT="$2"
    shift
    ;;
  -fp | --fish-start-port)
    FISH_START_PORT="$2"
    shift
    ;;
  -np | --node-start-port)
    NODE_START_PORT="$2"
    shift
    ;;
  -ap | --archive-start-port)
    ARCHIVE_START_PORT="$2"
    shift
    ;;
  -ll | --log-level)
    log_level="$2"
    shift
    ;;
  -fll | --file-log-level)
    file_log_level="$2"
    shift
    ;;
  -ph | --pg-host)
    PG_HOST="$2"
    shift
    ;;
  -pp | --pg-port)
    PG_PORT="$2"
    shift
    ;;
  -pu | --pg-user)
    PG_USER="$2"
    shift
    ;;
  -ppw | --pg-passwd)
    PG_PASSWD="$2"
    shift
    ;;
  -pd | --pg-db)
    PG_DB="$2"
    shift
    ;;
  -t | --transactions) transactions=true ;;
  -r | --reset) reset=true ;;
  -u | --update-genesis-timestamp) update_genesis_timestamp=true ;;
  -h | --help) help ;;
  *)
    echo "Unknown parameter passed: $1"
    exit 1
    ;;
  esac
  shift
done

# ================================================
# Check the PostgreSQL configuration required
# for Archive Node operation

if $archive; then
  echo "Archive Node spawning is enabled, we need to do the PostgreSQL communication check."
  echo "In case of any issues please make sure that you:"
  echo -e "\t1. Run the PostgreSQL server;"
  echo -e "\t2. Have configured PostgreSQL 'user';"
  echo -e "\t3. Have configured PostgreSQL 'database';"
  echo -e "\t\t3.1. psql -c 'CREATE DATABASE ${PG_DB}'"
  echo -e "\t\t3.2. psql ${PG_DB} < ./src/app/archive/create_schema.sql'"
  echo -e "\t4. Passed correct PostgreSQL data as CLI arguments to this script."

  psql postgresql://${PG_USER}:${PG_PASSWD}@${PG_HOST}:${PG_PORT}/${PG_DB} -c "SELECT * FROM user_commands;" &>/dev/null

  ARCHIVE_ADDRESS_CLI_ARG="-archive-address ${ARCHIVE_START_PORT}"
fi

# ================================================
# Configure the Seed Peer ID

SEED_PEER_ID="/ip4/127.0.0.1/tcp/$(($SEED_START_PORT + 2))/p2p/12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"

# ================================================
#

if $transactions; then
  if [ "$fish" -eq "0" ]; then
    echo "Sending transactions require at least one fish"
    exit
  fi
fi

printf "\n"
echo "Starting network with:"
echo -e "\t1 seed"

if $archive; then
  echo -e "\t1 archive"
fi

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
  printf "\n"

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
    --offline-whale-accounts-directory $ledgerfolder/offline_whale_keys \
    --offline-fish-accounts-directory $ledgerfolder/offline_fish_keys \
    --online-whale-accounts-directory $ledgerfolder/online_whale_keys \
    --online-fish-accounts-directory $ledgerfolder/online_fish_keys

  cp scripts/genesis_ledger.json $ledgerfolder/genesis_ledger.json
fi

snark_worker_pubkey=$(cat $ledgerfolder/snark_worker_keys/snark_worker_account.pub)

# ================================================
# Update the Genesis State Timestamp

config=$ledgerfolder/daemon.json

if $reset || $update_genesis_timestamp; then
  printf "\n"
  echo 'Updating Genesis State timestamp'

  jq "{genesis: {genesis_state_timestamp:\"$(date +"%Y-%m-%dT%H:%M:%S%z")\"}, ledger:.}" \
    <$ledgerfolder/genesis_ledger.json \
    >$config
fi

# ================================================
# Launch the Nodes

nodesfolder=$ledgerfolder/nodes

if $reset; then
  clean-dir $nodesfolder
  mkdir -p $nodesfolder/seed
fi

if $archive; then
  mkdir -p $nodesfolder/archive
fi

# ----------

if $archive; then
  printf "\n"
  echo 'Starting the Archive Node...'

  spawn-archive-node $nodesfolder/archive
  archive_pid=$!
fi

# ----------

spawn-node $nodesfolder/seed ${SEED_START_PORT} -seed -discovery-keypair $SEED_PEER_KEY ${ARCHIVE_ADDRESS_CLI_ARG}
seed_pid=$!

printf "\n"
echo 'Waiting for seed to go up...'

until $MINA_EXE client status -daemon-port ${SEED_START_PORT} &>/dev/null; do
  sleep 1
done

# ----------

snark_worker_flags="-snark-worker-fee $SNARK_WORKER_FEE -run-snark-worker $snark_worker_pubkey -work-selection seq"

for ((i = 0; i < $whales; i++)); do
  folder=$nodesfolder/whale_$i
  keyfile=$ledgerfolder/online_whale_keys/online_whale_account_$i
  mkdir -p $folder
  spawn-node $folder $(($WHALE_START_PORT + ($i * 5))) -peer $SEED_PEER_ID -block-producer-key $keyfile $snark_worker_flags ${ARCHIVE_ADDRESS_CLI_ARG}
  whale_pids[${i}]=$!
done

# ----------

for ((i = 0; i < $fish; i++)); do
  folder=$nodesfolder/fish_$i
  keyfile=$ledgerfolder/online_fish_keys/online_fish_account_$i
  mkdir -p $folder
  spawn-node $folder $(($FISH_START_PORT + ($i * 5))) -peer $SEED_PEER_ID -block-producer-key $keyfile $snark_worker_flags ${ARCHIVE_ADDRESS_CLI_ARG}
  fish_pids[${i}]=$!
done

# ----------

for ((i = 0; i < $nodes; i++)); do
  folder=$nodesfolder/node_$i
  mkdir -p $folder
  spawn-node $folder $(($NODE_START_PORT + ($i * 5))) -peer $SEED_PEER_ID ${ARCHIVE_ADDRESS_CLI_ARG}
  node_pids[${i}]=$!
done

# ================================================

printf "\n"
echo "Network participants information:"
printf "\n"

echo -e "\tSeed"
echo -e "\t\tInstance #0"
echo -e "\t\t  pid $seed_pid"
echo -e "\t\t  status: $MINA_EXE client status -daemon-port ${SEED_START_PORT}"
echo -e "\t\t  logs: cat $nodesfolder/seed/log.txt | $LOGPROC_EXE"

if [ "$whales" -gt "0" ]; then
  echo -e "\tWhales"
  for ((i = 0; i < $whales; i++)); do
    echo -e "\t\tInstance #$i"
    echo -e "\t\t  pid ${whale_pids[${i}]}"
    echo -e "\t\t  status: $MINA_EXE client status -daemon-port $(($WHALE_START_PORT + ($i * 5)))"
    echo -e "\t\t  logs: cat $nodesfolder/whale_$i/log.txt | $LOGPROC_EXE"
  done
fi

if [ "$fish" -gt "0" ]; then
  echo -e "\tFish"
  for ((i = 0; i < $fish; i++)); do
    echo -e "\t\tInstance #$i"
    echo -e "\t\t  pid ${fish_pids[${i}]}"
    echo -e "\t\t  status: $MINA_EXE client status -daemon-port $(($FISH_START_PORT + ($i * 5)))"
    echo -e "\t\t  logs: cat $nodesfolder/fish_$i/log.txt | $LOGPROC_EXE"
  done
fi

if [ "$nodes" -gt "0" ]; then
  echo -e "\tNon block-producing nodes"
  for ((i = 0; i < $nodes; i++)); do
    echo -e "\t\tInstance #$i"
    echo -e "\t\t  pid ${node_pids[${i}]}"
    echo -e "\t\t  status: $MINA_EXE client status -daemon-port $(($NODE_START_PORT + ($i * 5)))"
    echo -e "\t\t  logs: cat $nodesfolder/node_$i/log.txt | $LOGPROC_EXE"
  done
fi

if $archive; then
  echo -e "\tArchive"
  echo -e "\t\tInstance #0"
  echo -e "\t\t  pid $archive_pid"
  echo -e "\t\t  server-port: ${ARCHIVE_START_PORT}"
  echo -e "\t\t  logs: cat $nodesfolder/archive/log.txt | $LOGPROC_EXE"
fi

# ================================================
# Start sending transactions

if $transactions; then
  folder=$nodesfolder/fish_0
  keyfile=$ledgerfolder/online_fish_keys/online_fish_account_0
  pubkey=$(cat $ledgerfolder/online_fish_keys/online_fish_account_0.pub)
  rest_server="http://127.0.0.1:$(($FISH_START_PORT + 1))/graphql"
  printf "\n"
  echo "Waiting for node to be up to start sending transactions..."

  until $MINA_EXE client status -daemon-port $FISH_START_PORT &>/dev/null; do
    sleep 1
  done

  echo "Starting to send transactions every $transaction_frequency seconds"

  set +e

  $MINA_EXE account import -rest-server $rest_server -privkey-path $keyfile
  $MINA_EXE account unlock -rest-server $rest_server -public-key $pubkey

  sleep $TRANSACTION_FREQUENCY
  $MINA_EXE client send-payment -rest-server $rest_server -amount 1 -nonce 0 -receiver $pubkey -sender $pubkey

  while true; do
    sleep $TRANSACTION_FREQUENCY
    $MINA_EXE client send-payment -rest-server $rest_server -amount 1 -receiver $pubkey -sender $pubkey
  done

  set -e
fi

# ================================================
# Wait for nodes

wait

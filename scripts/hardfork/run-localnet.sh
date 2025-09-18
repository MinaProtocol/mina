#!/usr/bin/env bash

set -eox pipefail
set -T
PS4='debug($LINENO) ${FUNCNAME[0]:+${FUNCNAME[0]}}(): ';

export MINA_LIBP2P_PASS=
export MINA_PRIVKEY_PASS=
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Interval at which to send transactions
TX_INTERVAL=${TX_INTERVAL:-30s}

# Delay between now and genesis timestamp, in minutes
# Ignored if GENESIS_TIMESTAMP variable is specified
DELAY_MIN=${DELAY_MIN:-20}

# Allows to use develop ledger when equals to .develop
CONF_SUFFIX=${CONF_SUFFIX:-}

# Allows to specify a specific configuration file.
# If specified, ledger will not be generated.
# Specified config file is applied the latest and
# will override settings set by this script.
CUSTOM_CONF=${CUSTOM_CONF:-}

# Specify slot_tx_end parameter in the config
SLOT_TX_END=${SLOT_TX_END:-}

# Specify slot_chain_end parameter in the config
SLOT_CHAIN_END=${SLOT_CHAIN_END:-}

# Mina executable
MINA_EXE=${MINA_EXE:-mina}

# Genesis ledger directory
GENESIS_LEDGER_DIR=${GENESIS_LEDGER_DIR:-}

# Slot duration (a.k.a. block window duration), seconds
SLOT=${SLOT:-30}


# localnet mode (app or docker).
# Controls execution environment. If app is specified local mina app is used.
# Otherwise docker is used and all commands will be run in a docker container.
MODE=app

BP_CONTAINER_NAME=mina_bp
SW_CONTAINER_NAME=mina_sw

echo "Creates a quick-epoch-turnaround configuration in localnet/ and launches two Mina nodes" >&2
echo "Usage: $0 [-m|--mina $MINA_EXE] [--mina-docker $MINA_DOCKER] [-i|--tx-interval $TX_INTERVAL] [-d|--delay-min $DELAY_MIN] [-s|--slot $SLOT] [--develop] [-c|--config ./config.json] [--slot-tx-end 100] [--slot-chain-end 130] [--genesis-ledger-dir ./genesis]" >&2
echo "Consider reading script's code for information on optional arguments" >&2

##########################################################
# Parse arguments
##########################################################

while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--delay-min)
      DELAY_MIN="$2"; shift; shift ;;
    -i|--tx-interval)
      TX_INTERVAL="$2"; shift; shift ;;
    --develop)
      CONF_SUFFIX=".develop"; shift ;;
    -m|--mina)
      MODE=app
      MINA_EXE="$2"; shift; shift ;;
    --mina-docker)
      MODE=docker
      MINA_DOCKER="$2"; shift; shift ;;
    -s|--slot)
      SLOT="$2"; shift; shift ;;
    -c|--config)
      CUSTOM_CONF="$2"; shift; shift ;;
    --slot-chain-end)
      SLOT_CHAIN_END="$2"; shift; shift ;;
    --slot-tx-end)
      SLOT_TX_END="$2"; shift; shift ;;
    --genesis-ledger-dir)
      GENESIS_LEDGER_DIR="$2"; shift; shift ;;
    --bp-container-name)
      BP_CONTAINER_NAME="$2"; shift; shift ;;
    --sw-container-name)
      SW_CONTAINER_NAME="$2"; shift; shift ;;
    -*)
      echo "Unknown option $1"; exit 1 ;;
    *)
      KEYS+=("$1") ; shift ;;
  esac
done

if [[ "$CONF_SUFFIX" != "" ]] && [[ "$CUSTOM_CONF" != "" ]]; then
  echo "Can't use both --develop and --config options" >&2
  exit 1
fi

if [[ "$MINA_EXE" != "mina" ]] && [[ "$MINA_DOCKER" != "" ]]; then
  echo "Can't use both --mina and --mina-docker options" >&2
  exit 1
fi

# Check mina command exists
if [[ "$MODE" == "app" ]]; then
  command -v "$MINA_EXE" >/dev/null || { echo "No 'mina' executable found"; exit 1; }
fi

# Genesis timestamp to use in config
calculated_timestamp="$( d=$(date +%s); date -u -d @$((d - d % 60 + DELAY_MIN*60)) '+%F %H:%M:%S+00:00' )"
GENESIS_TIMESTAMP=${GENESIS_TIMESTAMP:-"$calculated_timestamp"}

##########################################################
# Generate configuration in localnet/config
##########################################################

CONF_DIR=localnet/config

mkdir -p $CONF_DIR
chmod 0700 $CONF_DIR

if [[ ! -f $CONF_DIR/bp ]]; then
  if [[ "$MODE" == "docker" ]]; then
    docker run --env MINA_LIBP2P_PASS --env MINA_PRIVKEY_PASS --rm -v "$PWD/localnet:/localnet" "$MINA_DOCKER" advanced generate-keypair --privkey-path /localnet/config/bp
  else
    "$MINA_EXE" advanced generate-keypair --privkey-path $CONF_DIR/bp
  fi
fi


if [[ "$MODE" == "docker" ]]; then
    NODE_ARGS_1=( --libp2p-keypair "/$CONF_DIR/libp2p_1" )
    NODE_ARGS_2=( --libp2p-keypair "/$CONF_DIR/libp2p_2" )
else
    NODE_ARGS_1=( --libp2p-keypair "$PWD/$CONF_DIR/libp2p_1" )
    NODE_ARGS_2=( --libp2p-keypair "$PWD/$CONF_DIR/libp2p_2" )
fi

if [[ "$MODE" == "docker" ]]; then
  docker run --env MINA_LIBP2P_PASS --env MINA_PRIVKEY_PASS --rm -v "$PWD/localnet:/localnet" "$MINA_DOCKER" libp2p generate-keypair --privkey-path /localnet/config/libp2p_1
  docker run --env MINA_LIBP2P_PASS --env MINA_PRIVKEY_PASS --rm -v "$PWD/localnet:/localnet" "$MINA_DOCKER" libp2p generate-keypair --privkey-path /localnet/config/libp2p_2
else
  "$MINA_EXE" libp2p generate-keypair --privkey-path $CONF_DIR/libp2p_1
  "$MINA_EXE" libp2p generate-keypair --privkey-path $CONF_DIR/libp2p_2
fi

if [[ "$CUSTOM_CONF" == "" ]] && [[ ! -f $CONF_DIR/ledger.json ]]; then
  ( cd $CONF_DIR && "$SCRIPT_DIR/../prepare-test-ledger.sh" --exit-on-old-ledger -c 100000 -b 1000000 "$(cat bp.pub)" >ledger.json )
fi

if [[ "$SLOT_TX_END" != "" ]]; then
  slot_ends=".daemon.slot_tx_end = $SLOT_TX_END | "
fi
if [[ "$SLOT_CHAIN_END" != "" ]]; then
  slot_ends="$slot_ends .daemon.slot_chain_end = $SLOT_CHAIN_END | "
fi

update_config_expr="$slot_ends .genesis.genesis_state_timestamp = \"$GENESIS_TIMESTAMP\""

jq "$update_config_expr" > $CONF_DIR/base.json << EOF
{
  "genesis": {
    "slots_per_epoch": 48,
    "k": 10,
    "grace_period_slots": 3
  },
  "proof": {
    "work_delay": 1,
    "level": "full",
    "transaction_capacity": { "2_to_the": 2 },
    "block_window_duration_ms": ${SLOT}000
  }
}
EOF

if [[ "$CUSTOM_CONF" == "" ]]; then
  { echo '{"ledger": {"accounts": '; cat $CONF_DIR/ledger.json; echo '}}'; } > $CONF_DIR/daemon.json
else
  cp "$CUSTOM_CONF" $CONF_DIR/daemon.json
fi
##############################################################
# Launch two Mina nodes and send transactions on an interval
##############################################################

COMMON_ARGS=( --file-log-level Info --log-level Error --seed )
COMMON_ARGS+=("--insecure-rest-server")

if [[ "$MODE" == "docker" ]]; then
  COMMON_ARGS+=( --config-file "/$CONF_DIR/base.json" )
  COMMON_ARGS+=( --config-file "/$CONF_DIR/daemon$CONF_SUFFIX.json" )
else
  COMMON_ARGS+=( --config-file "$PWD/$CONF_DIR/base.json" )
  COMMON_ARGS+=( --config-file "$PWD/$CONF_DIR/daemon$CONF_SUFFIX.json" )
fi

if [[ "$GENESIS_LEDGER_DIR" != "" ]]; then
  rm -Rf localnet/genesis_{1,2}
  cp -Rf "$GENESIS_LEDGER_DIR" localnet/genesis_1
  cp -Rf "$GENESIS_LEDGER_DIR" localnet/genesis_2
  if [[ "$MODE" == "docker" ]]; then
    NODE_ARGS_1+=( --genesis-ledger-dir "/localnet/genesis_1" )
    NODE_ARGS_2+=( --genesis-ledger-dir "/localnet/genesis_2" )
  else
    NODE_ARGS_1+=( --genesis-ledger-dir "$PWD/localnet/genesis_1" )
    NODE_ARGS_2+=( --genesis-ledger-dir "$PWD/localnet/genesis_2" )
  fi
fi

# Clean runtime directories
rm -Rf localnet/runtime_1 localnet/runtime_2


if [[ "$MODE" == "docker" ]]; then
   bp_container_id=$(docker run --name "$BP_CONTAINER_NAME" --env MINA_LIBP2P_PASS --env MINA_PRIVKEY_PASS -p 10301:10301 -p 10302:10302 -p 10303:10303 -d -v "$PWD/localnet:/localnet" "$MINA_DOCKER" daemon "${COMMON_ARGS[@]}" \
     --peer "/ip4/127.0.0.1/tcp/10312/p2p/$(cat $CONF_DIR/libp2p_2.peerid)" \
     "${NODE_ARGS_1[@]}" \
     --block-producer-key "/$CONF_DIR/bp" \
     --config-directory "/localnet/runtime_1" \
     --client-port 10301 --external-port 10302 --rest-port 10303 &
     )
   echo "Block producer container ID: $bp_container_id"
else
   "$MINA_EXE" daemon "${COMMON_ARGS[@]}" \
     --peer "/ip4/127.0.0.1/tcp/10312/p2p/$(cat $CONF_DIR/libp2p_2.peerid)" \
     "${NODE_ARGS_1[@]}" \
     --block-producer-key "$PWD/$CONF_DIR/bp" \
  --config-directory "$PWD/localnet/runtime_1" \
  --client-port 10301 --external-port 10302 --rest-port 10303 &
  bp_pid=$!
  echo "Block producer PID: $bp_pid"
fi

if [[ "$MODE" == "docker" ]]; then
  sw_container_id=$(docker run --name "$SW_CONTAINER_NAME" --env MINA_LIBP2P_PASS --env MINA_PRIVKEY_PASS -p 10311:10311 -p 10312:10312 -p 10313:10313 -d -v "$PWD/localnet:/localnet" "$MINA_DOCKER" daemon "${COMMON_ARGS[@]}" \
    --peer "/ip4/127.0.0.1/tcp/10302/p2p/$(cat $CONF_DIR/libp2p_1.peerid)" \
    "${NODE_ARGS_2[@]}" \
    --run-snark-worker "$(cat $CONF_DIR/bp.pub)" --work-selection seq \
    --config-directory "/localnet/runtime_2" \
    --client-port 10311 --external-port 10312 --rest-port 10313
    )
  echo "Snark worker container ID: $sw_container_id"

else
   "$MINA_EXE" daemon "${COMMON_ARGS[@]}" \
  "${NODE_ARGS_2[@]}" \
  --peer "/ip4/127.0.0.1/tcp/10302/p2p/$(cat $CONF_DIR/libp2p_1.peerid)" \
  --run-snark-worker "$(cat $CONF_DIR/bp.pub)" --work-selection seq \
  --config-directory "$PWD/localnet/runtime_2" \
  --client-port 10311 --external-port 10312 --rest-port 10313 &

  sw_pid=$!

  echo "Snark worker PID: $sw_pid"
fi

if [[ "$MODE" == "docker" ]]; then
  while ! docker exec --env MINA_LIBP2P_PASS --env MINA_PRIVKEY_PASS "$sw_container_id" mina accounts import --privkey-path "/$CONF_DIR/bp" --rest-server 10313 2>/dev/null; do
    sleep 1m
  done
else
  while ! "$MINA_EXE" accounts import --privkey-path "$PWD/$CONF_DIR/bp" --rest-server 10313 2>/dev/null; do
    sleep 1m
  done
fi

if [[ "$MODE" == "docker" ]]; then
  while ! docker exec --env MINA_LIBP2P_PASS --env MINA_PRIVKEY_PASS "$sw_container_id" mina ledger export staged-ledger --daemon-port 10311 > localnet/exported_staged_ledger.json; do
    sleep 1m
  done
else
  while ! "$MINA_EXE" ledger export staged-ledger --daemon-port 10311 > localnet/exported_staged_ledger.json; do
    sleep 1m
  done
fi

i=0

function check_if_mina_is_running() {
  if [[ "$MODE" == "docker" ]]; then
    docker container inspect "$sw_container_id" --format '{{.State.Status}}' | grep -q "running"
  else
    kill -0 $sw_pid 2>/dev/null
  fi
}

while check_if_mina_is_running; do
  # shuf's exit code is masked by `true` because we do not expect
  # all of the output to be read
  jq -r '.[].pk' < localnet/exported_staged_ledger.json | { shuf || true; } | while read acc; do
    if ! check_if_mina_is_running; then
      break
    fi

    if [[ "$MODE" == "docker" ]]; then
      docker exec --env MINA_LIBP2P_PASS --env MINA_PRIVKEY_PASS "$sw_container_id" bash -c "mina client send-payment --sender '$(cat $CONF_DIR/bp.pub)' --receiver '$acc' \
        --amount 0.1 --memo 'payment_$i' --rest-server 10313 2>/dev/null" \
        && i=$((i+1)) && echo "Sent tx #$i" || echo "Failed to send tx #$i"
    else
      "$MINA_EXE" client send-payment --sender "$(cat $CONF_DIR/bp.pub)" --receiver "$acc" \
        --amount 0.1 --memo "payment_$i" --rest-server 10313 2>/dev/null \
        && i=$((i+1)) && echo "Sent tx #$i" || echo "Failed to send tx #$i"
    fi
    sleep "$TX_INTERVAL"
  done
done

wait

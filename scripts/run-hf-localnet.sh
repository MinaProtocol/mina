#!/usr/bin/env bash

set -e
export MINA_LIBP2P_PASS=
export MINA_PRIVKEY_PASS=
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Interval at which to send transactions
TX_INTERVAL=${TX_INTERVAL:-30s}

# Delay between now and genesis timestamp, in minutes
DELAY_MIN=${DELAY_MIN:-20}

# Allows to use berkeley ledger when equals to .berkeley
CONF_SUFFIX=${CONF_SUFFIX:-}

# Allows to specify a specific configuration file
# Genesis timestamp will be updated before use of configuration file
CUSTOM_CONF=${CUSTOM_CONF:-}

# Specify slot_tx_end parameter in the config
SLOT_TX_END=${SLOT_TX_END:-}

# Specify slot_chain_end parameter in the config
SLOT_CHAIN_END=${SLOT_CHAIN_END:-}

# Mina executable
MINA_EXE=mina

echo "Creates a quick-epoch-turnaround configuration in localnet/ and launches two Mina nodes"
echo "Usage: $0 [-m|--mina $MINA_EXE] [-i|--tx-interval $TX_INTERVAL] [-d|--delay-min $DELAY_MIN] [-b|--berkeley]" >&2
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
    -b|--berkeley)
      CONF_SUFFIX=".berkeley"; shift ;;
    -m|--mina)
      MINA_EXE="$2"; shift; shift ;;
    -c|--config)
      CUSTOM_CONF="$2"; shift; shift ;;
    --slot-chain-end)
      SLOT_CHAIN_END="$2"; shift; shift ;;
    --slot-tx-end)
      SLOT_TX_END="$2"; shift; shift ;;
    -*|--*)
      echo "Unknown option $1"; exit 1 ;;
    *)
      KEYS+=("$1") ; shift ;;
  esac
done

if [[ "$CONF_SUFFIX" != "" ]] && [[ "$CUSTOM_CONF" != "" ]]; then
  echo "Can't use both --berkeley and --config options" >&2
  exit 1
fi

# Check mina command exists
command -v "$MINA_EXE" >/dev/null || { echo "No 'mina' executable found"; exit 1; }

##########################################################
# Generate configuration in localnet/config
##########################################################

CONF_DIR=localnet/config

mkdir -p $CONF_DIR
chmod 0700 $CONF_DIR

if [[ ! -f $CONF_DIR/bp ]]; then
  "$MINA_EXE" advanced generate-keypair --privkey-path $CONF_DIR/bp
fi

libp2p_1_args=( --libp2p-keypair "$PWD/$CONF_DIR/libp2p_1" )
libp2p_2_args=( --libp2p-keypair "$PWD/$CONF_DIR/libp2p_2" )
# We handle error of libp2p key generation because `compatible`'s version
# has a different command for libp2p key generation
if [[ ! -f $CONF_DIR/libp2p_1 ]]; then
  "$MINA_EXE" libp2p generate-keypair --privkey-path $CONF_DIR/libp2p_1 2>/dev/null || \
    libp2p_1_args=()
fi
if [[ ! -f $CONF_DIR/libp2p_2 ]]; then
  "$MINA_EXE" libp2p generate-keypair --privkey-path $CONF_DIR/libp2p_2 2>/dev/null || \
    libp2p_2_args=()
fi
if [[ "$CUSTOM_CONF" == "" ]] && [[ ! -f $CONF_DIR/ledger.json ]]; then
  ( cd $CONF_DIR && "$SCRIPT_DIR/prepare-test-ledger.sh" -c 100000 -b 1000000 $(cat bp.pub) >ledger.json )
fi

timestamp="$( d=$(date +%s); date -u -d @$((d - d % 60 + DELAY_MIN*60)) +%FT%H:%M:%S+00:00 )"

if [[ "$SLOT_TX_END" != "" ]]; then
  slot_ends=".daemon.slot_tx_end = $SLOT_TX_END | "
fi
if [[ "$SLOT_CHAIN_END" != "" ]]; then
  slot_ends="$slot_ends .daemon.slot_chain_end = $SLOT_CHAIN_END | "
fi

if [[ "$CUSTOM_CONF" == "" ]]; then
  jq --arg timestamp "$timestamp" --slurpfile accounts $CONF_DIR/ledger.json "$slot_ends .ledger.accounts = \$accounts[0] | .genesis.genesis_state_timestamp |= \$timestamp" > $CONF_DIR/daemon.json << EOF
{
  "genesis": {
    "genesis_state_timestamp": "",
    "slots_per_epoch": 48,
    "k": 2,
    "transaction_capacity": { "log_2": 2 },
    "grace_period_slots": 3
  },
  "proof": {
    "work_delay": 1,
    "block_window_duration_ms": 30000
  },
  "ledger": {
    "name": "localnet",
    "accounts": []
  }
}
EOF

  # Convert ledger to berkeley format
  jq '.ledger.accounts = [.ledger.accounts[] | del(.token_permissions, .permissions.stake) | .token = "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf" | .token_symbol = "" | select(.permissions.set_verification_key == "signature").permissions.set_verification_key |= {auth:"signature", txn_version: "1"} ]' <$CONF_DIR/daemon.json >$CONF_DIR/daemon.berkeley.json

else
  <"$CUSTOM_CONF" jq --arg timestamp "$timestamp" '.genesis.genesis_state_timestamp |= $timestamp' > $CONF_DIR/daemon.json
fi


##############################################################
# Launch two Mina nodes and send transactions on an interval
#############################################################

# Clean runtime directories
rm -Rf localnet/runtime_1 localnet/runtime_2

CONF_FILE="$PWD/$CONF_DIR/daemon$CONF_SUFFIX.json"

"$MINA_EXE" daemon --config-file "$CONF_FILE" \
  --peer "/ip4/127.0.0.1/tcp/10312/p2p/$(cat $CONF_DIR/libp2p_2.peerid)" \
  "${libp2p_1_args[@]}" --seed \
  --block-producer-key "$PWD/$CONF_DIR/bp" \
  --config-directory "$PWD/localnet/runtime_1" --file-log-level Info --log-level Error \
  --client-port 10301 --external-port 10302 --rest-port 10303 &

bp_pid=$!

echo "Block producer PID: $bp_pid"

"$MINA_EXE" daemon --config-file "$CONF_FILE" \
  "${libp2p_2_args[@]}"  --seed \
  --peer "/ip4/127.0.0.1/tcp/10302/p2p/$(cat $CONF_DIR/libp2p_1.peerid)" \
  --run-snark-worker "$(cat $CONF_DIR/bp.pub)" --work-selection seq \
  --config-directory "$PWD/localnet/runtime_2" --file-log-level Info --log-level Error \
  --client-port 10311 --external-port 10312 --rest-port 10313 &

sw_pid=$!

echo "Snark worker PID: $sw_pid"

while ! "$MINA_EXE" accounts import --privkey-path "$PWD/$CONF_DIR/bp" --rest-server 10313 2>/dev/null; do
  sleep 1m
done

i=0
while kill -0 $sw_pid; do
  <"$CONF_FILE" jq -r '.ledger.accounts[].pk' | shuf | while read acc; do
    if ! kill -0 $sw_pid; then
      exit 0
    fi
    "$MINA_EXE" client send-payment --sender "$(cat $CONF_DIR/bp.pub)" --receiver "$acc" \
      --amount 0.1 --memo "payment_$i" --rest-server 10313 2>/dev/null \
      && i=$((i+1)) && echo "Sent tx #$i" || echo "Failed to send tx #$i"
    sleep "$TX_INTERVAL"
  done
done

wait

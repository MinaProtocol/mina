#!/usr/bin/env bash

set -eox pipefail

set -T
PS4='debug($LINENO) ${FUNCNAME[0]:+${FUNCNAME[0]}}(): ';


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

SLOT_TX_END="${SLOT_TX_END:-30}"
SLOT_CHAIN_END="${SLOT_CHAIN_END:-$((SLOT_TX_END+8))}"

# Slot from which to start calling bestchain query
# to find last non-empty block
BEST_CHAIN_QUERY_FROM="${BEST_CHAIN_QUERY_FROM:-25}"

# Slot duration in seconds to be used for both version
MAIN_SLOT="${MAIN_SLOT:-15}"
FORK_SLOT="${FORK_SLOT:-15}"

# Delay before genesis slot in minutes to be used for both version
MAIN_DELAY="${MAIN_DELAY:-20}"
FORK_DELAY="${FORK_DELAY:-10}"

# script should be run from mina root directory.
# shellcheck disable=SC1090
source "$SCRIPT_DIR"/test-helper.sh

# Executable built off mainnet branch
MAIN_MINA_EXE=""
MAIN_RUNTIME_GENESIS_LEDGER_EXE=""

# Executables built off fork branch (e.g. develop)
FORK_MINA_EXE=""
FORK_RUNTIME_GENESIS_LEDGER_EXE=""

# env var needed when building debian packages
export BRANCH_NAME=$FORK_BRANCH

# skip adding ledgers to debian package as it will override genesis ledgers (we don't want that)
export DEBIAN_SKIP_LEDGERS_COPY=y


stop_nodes(){
  if [[ "$MODE" == "docker" ]]; then
    docker stop "$SW_CONTAINER_NAME"
    docker stop "$BP_CONTAINER_NAME"
    docker rm "$SW_CONTAINER_NAME"
    docker rm "$BP_CONTAINER_NAME"
  else
    "$1" client stop-daemon --daemon-port 10301
    "$1" client stop-daemon --daemon-port 10311
  fi
}

print_nodes_logs() {
  if [[ "$MODE" == "docker" ]]; then
    echo "Block producer logs:" >&2
    docker logs "$BP_CONTAINER_NAME" 2>&1 | tail -50
    echo "Block produces oversized logs:"
    docker exec "$BP_CONTAINER_NAME" bash -c 'head -c 100 /localnet/runtime_1/mina-oversized-logs.log'
    echo "SNARK worker logs:" >&2
    docker logs "$SW_CONTAINER_NAME" 2>&1 | tail -50
    echo "SNARK worker oversized logs:"
    docker exec "$SW_CONTAINER_NAME" bash -c 'head -c 100 /localnet/runtime_2/mina-oversized-logs.log'
  else
    echo "Node logs (if available):" >&2
    # Print any available log files
    for log_file in localnet/runtime_*/mina.log; do
      if [[ -f "$log_file" ]]; then
        echo "Log file: $log_file" >&2
        tail -50 "$log_file" 2>&1
      fi
    done
  fi
}

# Parse command line arguments

MINA_DOCKER=""
MODE="nix"

while [[ $# -gt 0 ]]; do
  case $1 in
    --mina-app)
      MAIN_MINA_EXE="$2"
      shift 2
      ;;
    --runtime-genesis-ledger)
      MAIN_RUNTIME_GENESIS_LEDGER_EXE="$2"
      shift 2
      ;;
    --fork-mina-app)
      FORK_MINA_EXE="$2"
      shift 2
      ;;
    --fork-runtime-genesis-ledger)
      FORK_RUNTIME_GENESIS_LEDGER_EXE="$2"
      shift 2
      ;;
    --mina-docker)
      MINA_DOCKER="$2"
      MODE="docker"
      BP_CONTAINER_NAME=mina_bp
      SW_CONTAINER_NAME=mina_sw
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ "$MODE" == "docker" && (-n "$MAIN_MINA_EXE" || -n "$MAIN_RUNTIME_GENESIS_LEDGER_EXE" || -n "$FORK_MINA_EXE" || -n "$FORK_RUNTIME_GENESIS_LEDGER_EXE") ]]; then
  echo "Error: Cannot specify both --mina-docker and native executable options (--mina-app, --runtime-genesis-ledger, --fork-mina-app, --fork-runtime-genesis-ledger)" >&2
  exit 1
fi

if [[ "$MODE" == "nix" ]]; then
  if [[ -z "$MAIN_MINA_EXE" || -z "$MAIN_RUNTIME_GENESIS_LEDGER_EXE" || -z "$FORK_MINA_EXE" || -z "$FORK_RUNTIME_GENESIS_LEDGER_EXE" ]]; then
    echo "Usage: $0 --mina-app <path> --runtime-genesis-ledger <path> --fork-mina-app <path> --fork-runtime-genesis-ledger <path> [--mina-docker <path>]" >&2
    exit 1
  fi
fi

# 1. Node is started
NOW_UNIX_TS=$(date +%s)
MAIN_GENESIS_UNIX_TS=$((NOW_UNIX_TS - NOW_UNIX_TS%60 + MAIN_DELAY*60))
GENESIS_TIMESTAMP="$(date -u -d @$MAIN_GENESIS_UNIX_TS '+%F %H:%M:%S+00:00')"
export GENESIS_TIMESTAMP

COMMON_ARGS=(
  -i "$MAIN_SLOT"
  -s "$MAIN_SLOT"
  --slot-tx-end "$SLOT_TX_END"
  --slot-chain-end "$SLOT_CHAIN_END"
)

if [[ "$MODE" == "docker" ]]; then
  "$SCRIPT_DIR"/run-localnet.sh --mina-docker "$MINA_DOCKER" \
     --bp-container-name "$BP_CONTAINER_NAME" \
     --sw-container-name "$SW_CONTAINER_NAME" \
     "${COMMON_ARGS[@]}" &
else
  "$SCRIPT_DIR"/run-localnet.sh -m "$MAIN_MINA_EXE" "${COMMON_ARGS[@]}" &
fi

MAIN_NETWORK_PID=$!

sleep $((MAIN_SLOT * BEST_CHAIN_QUERY_FROM - NOW_UNIX_TS%60 + MAIN_DELAY*60))s

# 2. Check that there are many blocks >50% of slots occupied from slot 0 to slot
# $BEST_CHAIN_QUERY_FROM and that there are some user commands in blocks corresponding to slots
if ! blockHeight=$(get_height 10303); then
  echo "Error: Failed to get block height from node" >&2
  echo "Printing logs for troubleshooting:" >&2
  print_nodes_logs
  stop_nodes "$MAIN_MINA_EXE"
  exit 3
fi
echo "Block height is $blockHeight at slot $BEST_CHAIN_QUERY_FROM."

if [[ $((10*blockHeight)) -lt $((3*BEST_CHAIN_QUERY_FROM)) ]]; then
  echo "Assertion failed: slot occupancy is below 30%" >&2
  print_nodes_logs
  stop_nodes "$MAIN_MINA_EXE"
  exit 3
fi

first_epoch_ne_str="$(blocks 10303 2>/dev/null | latest_nonempty_block)"
IFS=, read -ra first_epoch_ne <<< "$first_epoch_ne_str"

genesis_epoch_staking_hash="${first_epoch_ne[$((3+IX_CUR_EPOCH_HASH))]}"
genesis_epoch_next_hash="${first_epoch_ne[$((3+IX_NEXT_EPOCH_HASH))]}"

echo "Genesis epoch staking/next hashes: $genesis_epoch_staking_hash, $genesis_epoch_next_hash"

last_ne_str="$(for i in $(seq $BEST_CHAIN_QUERY_FROM $SLOT_CHAIN_END); do
  blocks $((10303+10*(i%2))) 2>/dev/null || true
  sleep "${MAIN_SLOT}s"
done | latest_nonempty_block)"

IFS=, read -ra latest_ne <<< "$last_ne_str"

# Maximum slot observed for a block
max_slot=${latest_ne[0]}

# List of epochs for which last snarked ledger hashes were captured
IFS=: read -ra epochs <<< "${latest_ne[1]}"
# List of last snarked ledger hashes captured
IFS=: read -ra last_snarked_hash_pe <<< "${latest_ne[2]}"

latest_ne=( "${latest_ne[@]:3}" )

echo "Last occupied slot of pre-fork chain: $max_slot"
if [[ $max_slot -ge $SLOT_CHAIN_END ]]; then
  echo "Assertion failed: block with slot $max_slot created after slot chain end" >&2
  stop_nodes "$MAIN_MINA_EXE"
  exit 3
fi

latest_shash="${latest_ne[$IX_STATE_HASH]}"
latest_height=${latest_ne[$IX_HEIGHT]}
latest_ne_slot=${latest_ne[$IX_SLOT]}

echo "Latest non-empty block: $latest_shash, height: $latest_height, slot: $latest_ne_slot"
if [[ $latest_ne_slot -ge $SLOT_TX_END ]]; then
  echo "Assertion failed: non-empty block with slot $latest_ne_slot created after slot tx end" >&2
  stop_nodes "$MAIN_MINA_EXE"
  exit 3
fi

expected_fork_data="{\"fork\":{\"blockchain_length\":$latest_height,\"global_slot_since_genesis\":$latest_ne_slot,\"state_hash\":\"$latest_shash\"},\"next_seed\":\"${latest_ne[$IX_NEXT_EPOCH_SEED]}\",\"staking_seed\":\"${latest_ne[$IX_CUR_EPOCH_SEED]}\"}"

# 4. Check that no new blocks are created
sleep 1m
height1=$(get_height 10303)
sleep 5m
height2=$(get_height 10303)
if [[ $(( height2 - height1 )) -gt 0 ]]; then
  echo "Assertion failed: there should be no change in blockheight after slot chain end." >&2
  stop_nodes "$MAIN_MINA_EXE"
  exit 3
fi

# 6. Transition root is extracted into a new runtime config
get_fork_config 10313 > localnet/fork_config.json

while [[ "$(stat -c %s localnet/fork_config.json)" == 0 ]] || [[ "$(head -c 4 localnet/fork_config.json)" == "null" ]]; do
  echo "Failed to fetch fork config" >&2
  sleep 1m
  get_fork_config 10313 > localnet/fork_config.json
done

# 7. Runtime config is converted with a script to have only ledger hashes in the config
stop_nodes "$MAIN_MINA_EXE"

fork_data="$(jq -cS '{fork:.proof.fork,next_seed:.epoch_data.next.seed,staking_seed:.epoch_data.staking.seed}' localnet/fork_config.json)"
if [[ "$fork_data" != "$expected_fork_data" ]]; then
  echo "Assertion failed: unexpected fork data" >&2
  exit 3
fi

if [[ "$MODE" == "docker" ]]; then
    docker run --rm -v "$PWD/localnet:/localnet" --entrypoint "mina-create-genesis" "$MINA_DOCKER" --config-file /localnet/fork_config.json --genesis-dir /localnet/prefork_hf_ledgers --hash-output-file /localnet/prefork_hf_ledger_hashes.json
else
    "$MAIN_RUNTIME_GENESIS_LEDGER_EXE" --config-file localnet/fork_config.json --genesis-dir localnet/prefork_hf_ledgers --hash-output-file localnet/prefork_hf_ledger_hashes.json
fi

# Finds staking ledger hash corresponding to an epoch given as $1 parameter
function find_staking_hash(){
  e=$1
  if [[ $e == 0 ]]; then
    echo "$genesis_epoch_staking_hash"
  elif [[ $e == 1 ]]; then
    echo "$genesis_epoch_next_hash"
  else
    ix=0
    e_=$((e-2))
    for el in "${epochs[@]}"; do
      [[ "$el" == "$e_" ]] && break
      ix=$((ix+1))
    done
    if [[ $ix == "${#epochs[@]}" ]]; then
      echo "Assertion failed: last snarked ledger for epoch $e_ wasn't captured" >&2
      exit 3
    fi
    echo "${last_snarked_hash_pe[$ix]}"
  fi
}

slot_tx_end_epoch=$((latest_ne_slot/48))

expected_staking_hash=$(find_staking_hash $slot_tx_end_epoch)
expected_next_hash=$(find_staking_hash $((slot_tx_end_epoch+1)))

expected_prefork_hashes="{\"epoch_data\":{\"next\":{\"hash\":\"$expected_next_hash\"},\"staking\":{\"hash\":\"$expected_staking_hash\"}},\"ledger\":{\"hash\":\"${latest_ne[$IX_STAGED_HASH]}\"}}"

# SHA3 hashes are not checked, because this is irrelevant to
# checking that correct ledgers are used
prefork_hashes_select='{epoch_data:{staking:{hash:.epoch_data.staking.hash},next:{hash:.epoch_data.next.hash}},ledger:{hash:.ledger.hash}}'

prefork_hashes="$(jq -cS "$prefork_hashes_select" localnet/prefork_hf_ledger_hashes.json)"
if [[ "$prefork_hashes" != "$expected_prefork_hashes" ]]; then
  echo "Assertion failed: unexpected ledgers in fork_config" >&2
  echo "Expected: $expected_prefork_hashes" >&2
  echo "Actual: $prefork_hashes" >&2
  exit 3
fi

rm -Rf localnet/hf_ledgers
mkdir localnet/hf_ledgers

source ./scripts/export-git-env-vars.sh

if [[ "$MODE" == docker ]]; then
  if [[ "$CONTEXT" == "local" ]]; then

    export RUNTIME_CONFIG_JSON="$PWD/localnet/fork_config.json"
    # shellcheck disable=SC2155
    export LEDGER_TARBALLS="$(echo $PWD/localnet/prefork_hf_ledgers/*.tar.gz)"

    ./scripts/debian/build.sh "daemon_devnet_hardfork"
    MINA_DEB_CODENAME=$MINA_DEB_CODENAME NETWORK_NAME=$NETWORK_NAME make hardfork-debian
    MINA_DEB_CODENAME=$MINA_DEB_CODENAME NETWORK_NAME=$NETWORK_NAME make hardfork-docker
  else

  docker run --rm  --env MINA_DEB_CODENAME --env NETWORK_NAME  --env OPAMSWITCH --env BYPASS_OPAM_SWITCH_UPDATE --env DUNE_PROFILE --env "AWS_ACCESS_KEY_ID" --env "AWS_SECRET_ACCESS_KEY" --env BYPASS_OPAM_SWITCH_UPDATE -v "$PWD:/workdir" -v /var/storagebox:/var/storagebox -w /workdir "$DOCKER_TOOLCHAIN" bash -c "
          sudo chown -R opam . \
          && source ~/.profile \
          && echo $DUNE_PROFILE \
          && git config --global --add safe.directory /workdir \
          && make libp2p_helper \
          && make build-logproc \
          && make build-devnet-sigs \
          && make build-daemon-utils \
          && make debian-build-logproc \
          && BACKEND=local make debian-download-create-legacy-hardfork \
          && RUNTIME_CONFIG_JSON=localnet/fork_config.json LEDGER_TARBALLS=\"$(echo /workdir/localnet/prefork_hf_ledgers/*.tar.gz)\" make hardfork-debian"

    OPAMSWITCH=4.14.2 BYPASS_OPAM_SWITCH_UPDATE=1 BRANCH_NAME=$BRANCH_NAME NETWORK_NAME=$NETWORK_NAME make hardfork-docker
    MINA_FORK_DOCKER=gcr.io/o1labs-192920/mina-daemon:$MINA_DEB_VERSION-$NETWORK_NAME
  fi
fi



if [[ "$MODE" == "docker" ]]; then
    docker run --rm -v "$PWD/localnet:/localnet" --entrypoint "mina-create-genesis" "$MINA_FORK_DOCKER" --config-file /localnet/fork_config.json --genesis-dir /localnet/hf_ledgers --hash-output-file /localnet/hf_ledger_hashes.json
else
    "$FORK_RUNTIME_GENESIS_LEDGER_EXE" --config-file localnet/fork_config.json --genesis-dir localnet/hf_ledgers --hash-output-file localnet/hf_ledger_hashes.json
fi

NOW_UNIX_TS=$(date +%s)
FORK_GENESIS_UNIX_TS=$((NOW_UNIX_TS - NOW_UNIX_TS%60 + FORK_DELAY*60))
GENESIS_TIMESTAMP="$( date -u -d @$FORK_GENESIS_UNIX_TS '+%F %H:%M:%S+00:00' )"
export GENESIS_TIMESTAMP
FORKING_FROM_CONFIG_JSON=localnet/config/base.json SECONDS_PER_SLOT="$MAIN_SLOT" FORK_CONFIG_JSON=localnet/fork_config.json LEDGER_HASHES_JSON=localnet/hf_ledger_hashes.json "$SCRIPT_DIR"/create_runtime_config.sh > localnet/config.json

expected_genesis_slot=$(((FORK_GENESIS_UNIX_TS-MAIN_GENESIS_UNIX_TS)/MAIN_SLOT))
expected_modified_fork_data="{\"blockchain_length\":$latest_height,\"global_slot_since_genesis\":$expected_genesis_slot,\"state_hash\":\"$latest_shash\"}"
modified_fork_data="$(jq -cS '.proof.fork' localnet/config.json)"
if [[ "$modified_fork_data" != "$expected_modified_fork_data" ]]; then
  echo "Assertion failed: unexpected modified fork data" >&2
  exit 3
fi

# TODO check ledgers in localnet/config.json

wait "$MAIN_NETWORK_PID"

echo "Config for the fork is correct, starting a new network"

# 8. Node is shutdown and restarted with mina-fork and the config from previous step 

if [[ "$MODE" == "docker" ]]; then
  "$SCRIPT_DIR"/run-localnet.sh --mina-docker "$MINA_FORK_DOCKER" \
     --bp-container-name "$BP_CONTAINER_NAME" \
     --sw-container-name "$SW_CONTAINER_NAME" \
     -d "$FORK_DELAY" \
     -i "$FORK_SLOT" \
     -s "$FORK_SLOT" \
     -c localnet/config.json \
     --genesis-ledger-dir localnet/hf_ledgers &
else
  "$SCRIPT_DIR"/run-localnet.sh -m "$FORK_MINA_EXE" -d "$FORK_DELAY" -i "$FORK_SLOT" \
  -s "$FORK_SLOT" -c localnet/config.json --genesis-ledger-dir localnet/hf_ledgers &

fi

sleep $((FORK_DELAY*60))s

earliest_str=""
while [[ "$earliest_str" == "" ]] || [[ "$earliest_str" == "," ]]; do
  earliest_str=$(get_height_and_slot_of_earliest 10303 2>/dev/null)
  sleep "$FORK_SLOT"s
done
IFS=, read -ra earliest <<< "$earliest_str"
earliest_height=${earliest[0]}
earliest_slot=${earliest[1]}
if [[ $earliest_height != $((latest_height+1)) ]]; then
  echo "Assertion failed: unexpected block height $earliest_height at the beginning of the fork" >&2
  print_nodes_logs
  stop_nodes "$FORK_MINA_EXE"
  exit 3
fi

if [[ $earliest_slot -lt $expected_genesis_slot ]]; then
  echo "Assertion failed: unexpected slot $earliest_slot at the beginning of the fork" >&2
  print_nodes_logs
  stop_nodes "$FORK_MINA_EXE"
  exit 3
fi

# 9. Check that network eventually creates some blocks

sleep $((FORK_SLOT*10))s
height1=$(get_height 10303)
if [[ $height1 == 0 ]]; then
  echo "Assertion failed: block height $height1 should be greater than 0." >&2
  print_nodes_logs
  stop_nodes "$FORK_MINA_EXE"
  exit 3
fi
echo "Blocks are produced."

# Wait and check that there are blocks created with >50% occupancy and there are transactions in last 10 blocks

all_blocks_empty=true
for i in {1..10}
do
  sleep "${FORK_SLOT}s"
  usercmds=$(blocks_with_user_commands 10303)
  if [[ $usercmds != 0 ]]; then
    all_blocks_empty=false
  fi
done
if $all_blocks_empty; then
  echo "Assertion failed: all blocks in fork chain are empty" >&2
  print_nodes_logs
  stop_nodes "$FORK_MINA_EXE"
  exit 3
fi

stop_nodes "$FORK_MINA_EXE"

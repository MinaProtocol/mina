#! /bin/bash

# Set defaults before parsing args
TESTNET=new-net
COMMUNITY_KEYFILE=""
RESET=false

WHALE_COUNT_UNIQUE=1
WHALE_COUNT_TOTAL=1
FISH_COUNT_UNIQUE=1
FISH_COUNT_TOTAL=1
SEED_COUNT=1
EXTRA_COUNT=1 # Extra community keys to be handed out manually

MINA_DAEMON_IMAGE="minaprotocol/mina-daemon:1.3.0beta1-develop-7af1312-buster-devnet"

WHALE_AMOUNT=2250000
FISH_AMOUNT=20000
O1_AMOUNT="${FISH_AMOUNT}"
COMMUNITY_AMOUNT=66000

while [ $# -gt 0 ]; do
  case "$1" in
    --testnet=*)
      TESTNET="${1#*=}"
      ;;
    --community-keyfile=*)
      COMMUNITY_KEYFILE="${1#*=}"
      ;;
    --reset=*)
      RESET="${1#*=}"
      ;;
    --wu=*)
      WHALE_COUNT_UNIQUE="${1#*=}"
      ;;
    --wt=*)
      WHALE_COUNT_TOTAL="${1#*=}"
      ;;
    --fu=*)
      FISH_COUNT_UNIQUE="${1#*=}"
      ;;
    --ft=*)
      FISH_COUNT_TOTAL="${1#*=}"
      ;;
    --sc=*)
      SEED_COUNT="${1#*=}"
      ;;
    --efc=*)
      EXTRA_COUNT="${1#*=}"
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

WHALE_AMOUNT=2250000
FISH_AMOUNT=20000
O1_AMOUNT="${FISH_AMOUNT}"
COMMUNITY_AMOUNT=66000

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd "${SCRIPTPATH}/../"
PATH=$PATH:$(pwd)/bin

if [[ -s $ARTIFACT_PATH/genesis_ledger.json ]]; then
  echo "exiting because a genesis ledger already exists in the testnet dir"
  exit 0
fi

if $RESET; then
  echo "resetting keys and genesis_ledger"
  ls keys/keysets/* | grep -v "bots_keyfiles" | xargs -I % rm "%"
  rm -rf keys/genesis keys/keypairs keys/testnet-keys
  rm -rf terraform/testnets/${TESTNET}/*.json
fi

# DIRS
mkdir -p ./keys/keysets
mkdir -p ./keys/keypairs
rm -rf ./keys/genesis && mkdir ./keys/genesis

set -eo pipefail
set -e

privkey_pass="naughty red vampire"

function generate_key_files {

  COUNT_UNIQUE=$1
  COUNT_TOTAL=$2
  name_prefix=$3
  output_dir="$4"
  mkdir -p $output_dir

  for k in $(seq 1 $COUNT_UNIQUE); do
    docker run \
      -v "${output_dir}:/keys:z" \
      --entrypoint /bin/bash $MINA_DAEMON_IMAGE \
      -c "MINA_PRIVKEY_PASS='${privkey_pass}' mina advanced generate-keypair -privkey-path /keys/${name_prefix}_account_${k}"
  done

  for k in $(seq 1 $COUNT_TOTAL); do
    docker run \
      --mount type=bind,source=${output_dir},target=/keys \
      --entrypoint /bin/bash $MINA_DAEMON_IMAGE \
      -c "MINA_LIBP2P_PASS='${privkey_pass}' mina advanced generate-libp2p-keypair -privkey-path /keys/${name_prefix}_libp2p_${k}"
  done

  # ensure proper r+w permissions for access to keys external to container
  docker run \
    -v "${output_dir}:/keys:z" \
    --entrypoint /bin/bash $MINA_DAEMON_IMAGE \
    -c "chmod -R +rw /keys"
}

function build_keyset_from_testnet_keys {
  output_dir=$1
  keyset_name=$2

  for file in $output_dir/*_account_*.pub; do
    nickname=$(basename $file .pub)
    jq -n ".publicKey = \"$(cat $file)\" | .nickname = \"$nickname\""
  done | jq -n ".name = \"${TESTNET}_${keyset_name}\" | .entries |= [inputs]" > keys/keysets/${TESTNET}_${keyset_name}
}

function generate_keyset_from_file {
  file=$1
  keyset=$2
  keys_name=$3

  declare -a PUBKEYS
  read -ra PUBKEYS <<< $(tr '\n' ' ' < ${file})
  COMMUNITY_SIZE=${#PUBKEYS[@]}
  echo "Generating $COMMUNITY_SIZE $keys_name keys..."

  if [[ -s "keys/testnet-keys/${TESTNET}_${keyset}" ]]; then
    echo "using existing ${keyset} keys"
  else

    k=1
    for key in ${PUBKEYS[@]}; do
      nickname=${TESTNET}_${keyset}${k}
      k=$(($k + 1))
      jq -n ".publicKey = \"$key\" | .nickname = \"$nickname\""
    done | jq -n ".name = \"${TESTNET}_${keyset}\" | .entries |= [inputs]" > keys/keysets/${TESTNET}_${keyset}

  fi

  echo "${keyset} Keyset:"
  cat keys/keysets/${TESTNET}_${keyset}
  echo

}
# ================================================================================

# prep dir for copied libp2psecrets
LIBP2PPEERS="$(pwd)/keys/libp2p/${TESTNET}/"
mkdir -p $LIBP2PPEERS

if [[ -s "keys/testnet-keys/${TESTNET}_online-whale-keyfiles/online_whale_account_1.pub" ]]; then
echo "using existing whale keys"
else
  online_output_dir="$(pwd)/keys/testnet-keys/${TESTNET}_online-whale-keyfiles"
  offline_output_dir="$(pwd)/keys/testnet-keys/${TESTNET}_offline-whale-keyfiles"

  generate_key_files $WHALE_COUNT_UNIQUE $WHALE_COUNT_TOTAL "online_whale" $online_output_dir
  generate_key_files $WHALE_COUNT_UNIQUE $WHALE_COUNT_TOTAL "offline_whale" $offline_output_dir

  build_keyset_from_testnet_keys $online_output_dir "online-whales"
  build_keyset_from_testnet_keys $offline_output_dir "offline-whales"
fi

online_output_dir="$(pwd)/keys/testnet-keys/${TESTNET}_online-whale-keyfiles"
cp ${online_output_dir}/*libp2p*.peerid ${LIBP2PPEERS}

echo "Online Whale Keyset:"
cat "keys/keysets/${TESTNET}_online-whales"
echo "Offline Whale Keyset:"
cat "keys/keysets/${TESTNET}_offline-whales"
echo

if [[ -s "keys/testnet-keys/${TESTNET}_online-fish-keyfiles/online_fish_account_1.pub" ]]; then
echo "using existing fish keys"
else
  online_output_dir="$(pwd)/keys/testnet-keys/${TESTNET}_online-fish-keyfiles"
  offline_output_dir="$(pwd)/keys/testnet-keys/${TESTNET}_offline-fish-keyfiles"

  generate_key_files $FISH_COUNT_UNIQUE $FISH_COUNT_TOTAL "online_fish" $online_output_dir
  generate_key_files $FISH_COUNT_UNIQUE $FISH_COUNT_TOTAL "offline_fish" $offline_output_dir

  build_keyset_from_testnet_keys $online_output_dir "online-fish"
  build_keyset_from_testnet_keys $offline_output_dir "offline-fish"
fi

online_output_dir="$(pwd)/keys/testnet-keys/${TESTNET}_online-fish-keyfiles"
cp ${online_output_dir}/*libp2p*.peerid ${LIBP2PPEERS}

echo "Online Fish Keyset:"
cat keys/keysets/${TESTNET}_online-fish
echo "Offline Fish Keyset:"
cat keys/keysets/${TESTNET}_offline-fish
echo

# TODO make this just check libp2p instead of unnecessarily generating seed public keys
if [[ -s "keys/testnet-keys/${TESTNET}_seed-keyfiles/online_seeds_account_1.pub" ]]; then
echo "using existing seed keys"
else
  online_output_dir="$(pwd)/keys/testnet-keys/${TESTNET}_seed-keyfiles"

  generate_key_files $SEED_COUNT $SEED_COUNT  "online_seeds" $online_output_dir

  build_keyset_from_testnet_keys $online_output_dir "online-seeds"

fi

online_output_dir="$(pwd)/keys/testnet-keys/${TESTNET}_seed-keyfiles"
cp ${online_output_dir}/*libp2p*.peerid ${LIBP2PPEERS}

if [[ -s "keys/libp2p/${TESTNET}/seed-1" ]]; then
  echo "libp2p keys prepped"
else
  echo "Prepping libp2p peers for consumption"
  for p2p in $LIBP2PPEERS*; do
    f="${p2p%.*}"
    base=$(basename $p2p)

    if [[ "$base" == *"fish"* ]]; then
      splitP2P=(${f//_/ })
      outputP2P="${splitP2P[1]}-block-producer-${splitP2P[3]}"
      mv ${p2p} ${LIBP2PPEERS}${outputP2P}
    fi

    if [[ "$base" == *"whale"* ]]; then
      splitP2P=(${f//_/ })
      outputP2P="${splitP2P[1]}-block-producer-${splitP2P[3]}"
      mv ${p2p} ${LIBP2PPEERS}${outputP2P}
    fi

    if [[ "$base" == *"seeds"* ]]; then
      splitP2P=(${f//_/ })
      outputP2P="seed-${splitP2P[3]}"
      mv ${p2p} ${LIBP2PPEERS}${outputP2P}
    fi
  done
fi

# ================================================================================

# ================================================================================

# EXTRA FISH
if [[ -s "keys/testnet-keys/${TESTNET}_extra-fish-keyfiles/extra_fish_account_1.pub" ]]; then
echo "using existing fish keys"
else
  output_dir="$(pwd)/keys/testnet-keys/${TESTNET}_extra-fish-keyfiles"
  generate_key_files $EXTRA_COUNT $EXTRA_COUNT "extra_fish" $output_dir

  build_keyset_from_testnet_keys $output_dir "extra-fish"
fi

echo "Extra Fish Keyset:"
cat keys/keysets/${TESTNET}_extra-fish
echo

# ================================================================================

if [ ! -z $COMMUNITY_KEYFILE ]; then
  generate_keyset_from_file $COMMUNITY_KEYFILE "online-community" "community"
else
  echo "community keys disabled"
fi
# ================================================================================

# o1-keys.txt was out-of-date and now does not exist
# create a new o1-keys.txt and uncomment this to add employee keys to a future network
# generate_keyset_from_file "o1-keys.txt" "online-o1" "employee"

# ================================================================================

# Bots

echo "generating bots keys"

if [ -d keys/testnet-keys/bots_keyfiles ];
then
  echo "Bots keys already present, not generating new ones"
else
  output_dir="$(pwd)/keys/testnet-keys/bots_keyfiles/"
  generate_key_files 2 2 "bots_keyfiles" "${output_dir}"

  build_keyset_from_testnet_keys "${output_dir}" "bots_keyfiles"

  mv ${output_dir}/bots_keyfiles_account_1.pub ${output_dir}/echo_service.pub
  mv ${output_dir}/bots_keyfiles_account_1 ${output_dir}/echo_service
  mv ${output_dir}/bots_keyfiles_account_2.pub ${output_dir}/faucet_service.pub
  mv ${output_dir}/bots_keyfiles_account_2 ${output_dir}/faucet_service
fi

# ================================================================================

# GENESIS

echo "making genesis ledger"

if [[ -s "terraform/testnets/${TESTNET}/genesis_ledger.json" ]] ; then
  echo "-- genesis_ledger.json already exists for this testnet, refusing to overwrite. Delete \'terraform/testnets/${TESTNET}/genesis_ledger.json\' to force re-creation."
  exit
fi

#if $COMMUNITY_ENABLED ; then
#    echo "-- Creating genesis ledger with 'coda-network genesis' --"
#else
#  echo "-- Creating genesis ledger with 'coda-network genesis' without community keys --"

PROMPT_KEYSETS=""
function add_another_to_prompt {
  from=$1
  amount=$2
  to=$3

  if [ -z $to ]; then
    to=$from
  fi

  PROMPT_KEYSETS="${PROMPT_KEYSETS}y
  ${from}
  ${amount}
  ${to}
  "
}

#COMMUNITY_TIMING=terraform/testnets/${TESTNET}/community_timing.json

function dynamic_keysets {
  from=$1

  case $from in
    *line-fish)
      amount=${FISH_AMOUNT}
      to=${TESTNET}_online-fish
      ;;
    *line-whales)
      amount=${WHALE_AMOUNT}
      to=${TESTNET}_online-whales
      ;;
    *community*)
      amount=${COMMUNITY_AMOUNT}
      to=${2}
      ;;
    *o1)
      amount=${O1_AMOUNT}
      to=${2}
      ;;
    *)
      amount=$3
      to=$2
  esac

  if [ -z $to ]; then
    to=$from
  fi

  echo -e "y\n${from}\n${amount}\n${to}"
}


# add initial keyset
PROMPT_KEYSETS="${TESTNET}_extra-fish
${COMMUNITY_AMOUNT}
${TESTNET}_extra-fish
"
add_another_to_prompt ${TESTNET}_offline-whales ${WHALE_AMOUNT} ${TESTNET}_online-whales
add_another_to_prompt ${TESTNET}_offline-fish ${FISH_AMOUNT} ${TESTNET}_online-fish
add_another_to_prompt ${TESTNET}_online-fish ${FISH_AMOUNT} ${TESTNET}_online-fish
# add_another_to_prompt ${TESTNET}_online-o1 ${FISH_AMOUNT} ${TESTNET}_online-o1

if [ -s keys/keysets/${TESTNET}_bots_keyfiles ];
then
  add_another_to_prompt ${TESTNET}_bots_keyfiles 50000 ${TESTNET}_bots_keyfiles
else
  echo "Bots keyset is missing, building ledger without them"
fi

# set not another keyset
PROMPT_KEYSETS="${PROMPT_KEYSETS}n
"

# Handle passing the above keyset info into interactive 'coda-network genesis' prompts
while read input
do echo "$input"
  sleep 5
done < <(echo -n "$PROMPT_KEYSETS") | coda-network genesis

GENESIS_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Fix the ledger format for ease of use
echo "Rewriting ./keys/genesis/* as ${ARTIFACT_PATH}/genesis_ledger.json in the proper format for daemon consumption..."
cat ./keys/genesis/* | jq '.[] | select(.balance=="'${WHALE_AMOUNT}'") | . + { sk: null, delegate: .delegate, balance: (.balance + ".000000000") }' | cat > "${ARTIFACT_PATH}/whales.accounts.json"
cat ./keys/genesis/* | jq '.[] | select(.balance=="'${FISH_AMOUNT}'") | . + { sk: null, delegate: .delegate, balance: (.balance + ".000000000") }' | cat > "${ARTIFACT_PATH}/fish.accounts.json"
cat ./keys/genesis/* | jq '.[] | select(.balance=="'${COMMUNITY_AMOUNT}'") | . + { sk: null, delegate: .delegate, balance: (.balance + ".000000000"), timing: { initial_minimum_balance: "60000", cliff_time:"150", cliff_amount:"12000", vesting_period:"6", vesting_increment:"150"}}' | cat > "${ARTIFACT_PATH}/community_fast_unlock.accounts.json"

echo "Determining total accounts based on partial ledgers..."
NUM_ACCOUNTS=$(jq -s 'length'  ${ARTIFACT_PATH}/*.json)

echo "Merging partial ledgers into genesis_ledger..."
jq -s '{ genesis: { genesis_state_timestamp: "'${GENESIS_TIMESTAMP}'" }, ledger: { name: "'${TESTNET}'", num_accounts: '${NUM_ACCOUNTS}', accounts: [ .[] ] } }' ${ARTIFACT_PATH}/*.accounts.json > "${ARTIFACT_PATH}/genesis_ledger.json"

echo "Keys and genesis ledger generated successfully, $TESTNET is ready to deploy!"

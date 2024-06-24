#! /bin/bash
MINA_DAEMON_IMAGE="minaprotocol/mina-daemon:1.3.2beta2-release-2.0.0-6f9d956-focal-berkeley"

while [ $# -gt 0 ]; do
  case "$1" in
    --testnet=*)
      TESTNET="${1#*=}"
      ;;
    --reset=*)
      RESET="${1#*=}"
      ;;
    --whales=*)
      WHALES="${1#*=}"
      ;;
    --fish=*)
      FISH="${1#*=}"
      ;;
    --seeds=*)
      SEEDS="${1#*=}"
      ;;
    --privkey-pass=*)
      PRIVKEY_PASS="${1#*=}"
      ;;
    # --artifact-path=*)
    #   ARTIFACT_PATH="${1#*=}"
    #   ;;
  esac
  shift
done

TOTAL_KEYS=$(( $WHALES + $FISH ))

WHALE_AMOUNT=2250000

FISH_AMOUNT=375000

KEYSDIR="./keys"

if [[ -d "$KEYSDIR" ]]
then 
  echo "keys directory and genesis ledger already exists"
  read -r -p "Are you sure you want to overwrite it? [any response other than 'y' will exit] " RESPONSE
  case "$RESPONSE" in
    [yY]) 
        rm -rf "$KEYSDIR"
        rm ./*.accounts.json
        rm ./genesis_ledger.json
        echo "keysdir and genesis ledger deleted, continuing"
        ;;
    *)
        exit 1
        ;;
  esac
fi

mkdir "$KEYSDIR"

export MINA_PRIVKEY_PASS="${PRIVKEY_PASS}"
export MINA_LIBP2P_PASS="${PRIVKEY_PASS}"

echo "generating whale keys"
for i in $(seq 1 $WHALES); do
    mina advanced generate-keypair --privkey-path "${KEYSDIR}/whale-${i}" 2>/dev/null
done

echo "generating fish keys"
for i in $(seq 1 $FISH); do
    mina advanced generate-keypair --privkey-path "${KEYSDIR}/fish-${i}" 2>/dev/null
done

echo "generating seeds' libp2p keys"
mkdir "${KEYSDIR}/libp2p-keys"
for i in $(seq 1 $SEEDS); do
    mina libp2p generate-keypair --privkey-path "${KEYSDIR}/libp2p-keys/seed-${i}" 2>/dev/null
done


echo "creating partial whale and fish json account objects"
cat ${KEYSDIR}/whale-*.pub | jq -R '{"pk": ., "delegate": ., "sk": null, "balance": "'${WHALE_AMOUNT}'.000000000" }' > ./whales.accounts.json
cat ${KEYSDIR}/fish-*.pub | jq -R '{"pk": ., "delegate": ., "sk": null, "balance": "'${FISH_AMOUNT}'.000000000" }' > ./fish.accounts.json

GENESIS_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "Merging partial ledgers into genesis_ledger..."
jq -s '{ genesis: { genesis_state_timestamp: "'${GENESIS_TIMESTAMP}'" }, ledger: { name: "'${TESTNET}'", accounts: [ .[] ] } }' ./*.accounts.json > "./genesis_ledger.json"


rm ./*.accounts.json
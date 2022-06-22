#! /bin/bash

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
    --zkapp-accounts=*)
      ZKAPP_ACCOUNTS="${1#*=}"
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

TOTAL_KEYS=$(( $WHALES + $FISH + $ZKAPP_ACCOUNTS ))

WHALE_AMOUNT=2250000

FISH_AMOUNT=375000

ZKAPP_AMOUNT=2250000

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
    ~/repos/mina/_build/default/src/app/cli/src/mina.exe advanced generate-keypair --privkey-path "${KEYSDIR}/whale-${i}" 2>/dev/null
done

echo "generating fish keys"
for i in $(seq 1 $FISH); do
    ~/repos/mina/_build/default/src/app/cli/src/mina.exe advanced generate-keypair --privkey-path "${KEYSDIR}/fish-${i}" 2>/dev/null
done

echo "generating zkapp account keys"
for i in $(seq 1 $ZKAPP_ACCOUNTS); do
    ~/repos/mina/_build/default/src/app/cli/src/mina.exe advanced generate-keypair --privkey-path "${KEYSDIR}/zkapp-${i}" 2>/dev/null
done

echo "generating seeds' libp2p keys"
mkdir "${KEYSDIR}/libp2p-keys"
for i in $(seq 1 $SEEDS); do
    ~/repos/mina/_build/default/src/app/cli/src/mina.exe advanced generate-libp2p-keypair --privkey-path "${KEYSDIR}/libp2p-keys/seed-${i}" 2>/dev/null
done


echo "creating partial whale and fish json account objects"
cat ${KEYSDIR}/whale-*.pub | jq -R '{"pk": ., "delegate": ., "sk": null, "balance": "'${WHALE_AMOUNT}'.000000000" }' > ./whales.accounts.json
cat ${KEYSDIR}/fish-*.pub | jq -R '{"pk": ., "delegate": ., "sk": null, "balance": "'${FISH_AMOUNT}'.000000000" }' > ./fish.accounts.json
cat ${KEYSDIR}/zkapp-*.pub | jq -R '
{
  "pk": .,
  "balance": "'${ZKAPP_AMOUNT}'.000000000",
  "delegate": .,
  "zkapp": {
      "state": [ "0", "0", "0", "0", "0", "0", "0", "0" ],
      "verification_key":
        "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",
      "zkapp_version": "0",
      "sequence_state": [
        "19777675955122618431670853529822242067051263606115426372178827525373304476695",
        "19777675955122618431670853529822242067051263606115426372178827525373304476695",
        "19777675955122618431670853529822242067051263606115426372178827525373304476695",
        "19777675955122618431670853529822242067051263606115426372178827525373304476695",
        "19777675955122618431670853529822242067051263606115426372178827525373304476695"
      ],
      "last_sequence_slot": 0,
      "proved_state": false
  },
  "permissions": {
    "edit_state": "signature",
    "send": "signature",
    "set_delegate": "signature",
    "set_permissions": "signature",
    "set_verification_key": "signature",
    "set_zkapp_uri": "signature",
    "edit_sequence_state": "signature",
    "set_token_symbol": "signature",
    "increment_nonce": "signature",
    "set_voting_for": "signature"
  }
}' > ./zkapp.accounts.json

GENESIS_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "Merging partial ledgers into genesis_ledger..."
jq -s '{ genesis: { genesis_state_timestamp: "'${GENESIS_TIMESTAMP}'" }, ledger: { name: "'${TESTNET}'", accounts: [ .[] ] } }' ./*.accounts.json > "./genesis_ledger.json"


rm ./*.accounts.json
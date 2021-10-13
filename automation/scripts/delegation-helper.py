import jsonlines 
import json

# Load STAKING_CHALLENGE dict 
exec(open("./testnet-tools/pubkey_to_discord.py").read())

KNOWN_KEYS = json.load(open("../services/testnet-points/known_keys.json"))

observed_keys = {}
with jsonlines.open('/Users/connerswann/Desktop/ledger.json') as reader:
    for obj in reader:
        balance = int(obj["balance"])
        public_key = obj["public_key"]
        delegate = obj["delegate"]

        observed_keys[public_key] = obj

for key in observed_keys.keys():
    obj = observed_keys[key]
    balance = int(obj["balance"])
    public_key = obj["public_key"]
    delegate = obj["delegate"]

    if balance > 50000:
        print("Found a whale account: ", public_key)

        print("\t Delegating to -> ", delegate)
        print("\t Discord: ", STAKING_CHALLENGE.get(delegate) if STAKING_CHALLENGE.get(delegate) else KNOWN_KEYS.get(delegate))
        print("\t Delegates balance: ", observed_keys[delegate]["balance"])
        print()

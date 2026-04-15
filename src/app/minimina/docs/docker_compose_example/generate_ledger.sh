#!/bin/bash

# Define the path to the block producer keys
declare bp_dir=~/.minimina/default/block_producer_keys

# Read the contents of the public key files
declare mina_bp_1_key=$(<"$bp_dir/mina-bp-1.pub")
declare mina_bp_2_key=$(<"$bp_dir/mina-bp-2.pub")

# Write the JSON structure to ~/.minimina/default/genesis_ledger.json
declare genesis_ledger_path=~/.minimina/default/genesis_ledger.json
cat <<EOF > $genesis_ledger_path
{
  "genesis": {
    "genesis_state_timestamp": "2023-08-16T17:45:29+0200"
  },
  "ledger": {
    "name": "release",
    "num_accounts": 250,
    "accounts": [
     {
      "pk": "$mina_bp_1_key",
      "sk": null,
      "balance": "11550000.000000000",
      "delegate": null
     },
     {
      "pk": "$mina_bp_2_key",
      "sk": null,
      "balance": "11550000.000000000",
      "delegate": null
     }
    ]
  }
}
EOF

echo "Generated genesis ledger file in $genesis_ledger_path including keys:"
echo "Key 1: $mina_bp_1_key"
echo "Key 2: $mina_bp_2_key"

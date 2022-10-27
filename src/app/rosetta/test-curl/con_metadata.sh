#!/bin/bash

. lib.sh

REQ='{
    "network_identifier": {
        "blockchain": "mina",
        "network": "debug"
    },
    "options": {
      "sender": "B62qjBWBUHVNYVb5KvZbmwiiVL85sELU6c56w8Ci3nBf4oShNb47mXy",
      "token_id":"1",
      "receiver": "B62qrjd1WHd9ZjpXisrUREkiY3KwsdjhhUXpM8M6qymHbgqzX6nmEcx"
    },
    "public_keys": [
        {
            "hex_bytes": "string",
            "curve_type": "pallas"
        }
    ]
}'

# req '/construction/metadata' '{"network_identifier":{"blockchain":"mina","network":"debug"},"options":{"sender":"B62qmnkbvNpNvxJ9FkSkBy5W6VkquHbgN2MDHh1P8mRVX3FQ1eWtcxV","token_id":"1"},"public_keys":[]}'

req '/construction/metadata' "$REQ"


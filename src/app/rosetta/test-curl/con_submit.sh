#!/bin/bash

. lib.sh

req '/construction/submit' '{"network_identifier": { "blockchain": "mina", "network": "devnet" }, "signed_transaction": "{\"signature\":\"36A4385223C49079A41ABEFD289C002666320DCA3074B7655C19D923FE961D252B31A7AF894487A78BF2C4CF441BC33FF88B123AC44676BCB09BECCCDA8AB9C1\",\"payment\":{\"to\":\"B62qoDWfBZUxKpaoQCoFqr12wkaY84FrhxXNXzgBkMUi2Tz4K8kBDiv\",\"from\":\"B62qkUHaJUHERZuCHQhXCQ8xsGBqyYSgjQsKnKN5HhSJecakuJ4pYyk\",\"fee\":\"2000000000\",\"token\":\"1\",\"nonce\":\"2\",\"memo\":\"hello\",\"amount\":\"3000000000\",\"valid_until\":\"10000000\"},\"stake_delegation\":null,\"create_token\":null,\"create_token_account\":null,\"mint_tokens\":null}"}'

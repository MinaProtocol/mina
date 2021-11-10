#!/bin/bash

. lib.sh

req '/construction/submit' '{"network_identifier": { "blockchain": "mina", "network": "devnet" }, "signed_transaction": "{\"signature\":\"2254F756B4149F76414D88AE1D5BE74EED21B3D9B514093CB8984B87C40CB17E27C066716595B701554DFA55F96707EAEE252CBE7859C0820468B93940C219F9\",\"payment\":{\"to\":\"B62qoDWfBZUxKpaoQCoFqr12wkaY84FrhxXNXzgBkMUi2Tz4K8kBDiv\",\"from\":\"B62qkUHaJUHERZuCHQhXCQ8xsGBqyYSgjQsKnKN5HhSJecakuJ4pYyk\",\"fee\":\"2000000000\",\"token\":\"1\",\"nonce\":\"1\",\"memo\":\"hello\",\"amount\":\"3000000000\",\"valid_until\":\"10000000\"},\"stake_delegation\":null,\"create_token\":null,\"create_token_account\":null,\"mint_tokens\":null}"}'

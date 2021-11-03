#!/bin/bash

. lib.sh

req '/construction/submit' '{"network_identifier": { "blockchain": "mina", "network": "devnet" }, "signed_transaction": "{\"signature\":\"23826DCE9B942EB4495FBD9340D0E79FF9F29774D654A85EF1FC829501AEF6323E5D7F1D0C131E429110689EE078E9A321A4965571155FFE182B73CEF54EF2D8\",\"payment\":{\"to\":\"B62qoDWfBZUxKpaoQCoFqr12wkaY84FrhxXNXzgBkMUi2Tz4K8kBDiv\",\"from\":\"B62qkUHaJUHERZuCHQhXCQ8xsGBqyYSgjQsKnKN5HhSJecakuJ4pYyk\",\"fee\":\"2000000000\",\"token\":\"1\",\"nonce\":\"1\",\"memo\":\"hello\",\"amount\":\"3000000000\",\"valid_until\":\"100\"},\"stake_delegation\":null,\"create_token\":null,\"create_token_account\":null,\"mint_tokens\":null}"}'

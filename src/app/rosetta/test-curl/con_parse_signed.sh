#!/bin/bash

. lib.sh

req '/construction/parse' '{"network_identifier":{"blockchain":"mina","network":"debug"},"signed":true,"transaction":"{\"signature\":\"251d96fe23d9195c65b77430ca0d326626009c28fdbe1aa47990c4235238a436c1b98adaccec9bb0bc7646c43a128bf83fc31b44cfc4f28ba7874489afa7312b\",\"payment\":{\"to\":\"B62qoDWfBZUxKpaoQCoFqr12wkaY84FrhxXNXzgBkMUi2Tz4K8kBDiv\",\"from\":\"B62qkUHaJUHERZuCHQhXCQ8xsGBqyYSgjQsKnKN5HhSJecakuJ4pYyk\",\"fee\":\"2000000000\",\"token\":\"1\",\"nonce\":\"2\",\"memo\":\"hello\",\"amount\":\"3000000000\",\"valid_until\":\"10000000\"},\"stake_delegation\":null,\"create_token\":null,\"create_token_account\":null,\"mint_tokens\":null}"}'

get_height()
{ curl --location "http://localhost:${1}/graphql" \
--header "Content-Type: application/json" \
--data "{\"query\":\"query MyQuery {\n  version\n  bestChain {\n    protocolState {\n      consensusState {\n        blockHeight\n      }\n    }\n  }\n}\",\"variables\":{}}" \
| jq -r '.data.bestChain[-1].protocolState.consensusState.blockHeight'
}

get_fork_config()
{ curl --location "http://localhost:${1}/graphql" \
--header "Content-Type: application/json" \
--data "{\"query\":\"query MyQuery {\n  fork_config\n}\n\",\"variables\":{}}" | jq '.data.fork_config'
}

blocks_withUserCommands()
{ curl --location "http://localhost:${1}/graphql" \
--header "Content-Type: application/json" \
--data "{\"query\":\"query MyQuery {\n  version\n  bestChain(maxLength: 10) {\n    commandTransactionCount\n  }\n}\",\"variables\":{}}" \
| jq -r '[.data.bestChain[] | select(.commandTransactionCount>0)] | length'
}
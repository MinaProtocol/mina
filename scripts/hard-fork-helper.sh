get_height()
{ curl --location "http://localhost:${1}/graphql" \
--header "Content-Type: application/json" \
--data "{\"query\":\"query MyQuery {\n  version\n  bestChain {\n    protocolState {\n      consensusState {\n        blockHeight\n      }\n    }\n  }\n}\",\"variables\":{}}" \
| jq '.data.bestChain[-1].protocolState.consensusState.blockHeight'
}

get_fork_config(){
    curl --location "http://localhost:${1}/graphql" \
--header 'Content-Type: application/json' \
--data '{"query":"query MyQuery {\n  fork_config\n}\n","variables":{}}' | jq '.data.fork_config'
}

wait_for_block() {
    height=$(get_height)
    if [[ -z $1 ]]; then
        expected=$((height + 1))
    else
        expected=$1
    fi
    echo "Waiting for block $expected..."
    while [[ $height -lt "$expected" ]]; do
        sleep 2
        height="$(get_height)"
    done
    echo "At block #$height."
}

check_userCommands(){
    curl --location "http://localhost:${1}/graphql" \
--header "Content-Type: application/json" \
--data "{\"query\":\"query MyQuery {\n  version\n  bestChain(maxLength: 10) {\n    commandTransactionCount\n  }\n}\",\"variables\":{}}" \
| jq 'any(.data.bestChain[]; .commandTransactionCount >0)'
}

blocks_withUserCommands(){
    curl --location "http://localhost:${1}/graphql"\
--header "Content-Type: application/json" \
--data "{\"query\":\"query MyQuery {\n  version\n  bestChain(maxLength: 10) {\n    commandTransactionCount\n  }\n}\",\"variables\":{}}" \
| jq '[.data.bestChain[] | select(.commandTransactionCount>0)] | length'
}
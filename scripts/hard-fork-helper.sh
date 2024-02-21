graphql()
{ curl --location "http://localhost:$1/graphql" \
--header "Content-Type: application/json" \
--data "{\"query\":\"query Q {$2}\"}"
}

get_height_and_slot_of_earliest()
{ graphql "$1" 'bestChain { protocolState { consensusState { blockHeight slotSinceGenesis } } }' \
| jq -r '.data.bestChain[0].protocolState.consensusState | .blockHeight + "," + .slotSinceGenesis'
}

get_height()
{ graphql "$1" 'bestChain(maxLength: 1) { protocolState { consensusState { blockHeight } } }' \
| jq -r '.data.bestChain[-1].protocolState.consensusState.blockHeight'
}

get_fork_config()
{ graphql "$1" 'fork_config' | jq '.data.fork_config'
}

blocks_with_user_commands()
{ graphql "$1" 'bestChain { commandTransactionCount }' \
| jq -r '[.data.bestChain[] | select(.commandTransactionCount>0)] | length'
}

blocks_query="$(cat << EOF
bestChain {
  commandTransactionCount
  protocolState {
    consensusState {
      blockHeight
      slotSinceGenesis
    }
  }
  transactions {
    coinbase
    feeTransfer {
      fee
    }
  }
  stateHash
}
EOF
)"

blocks_filter='.data.bestChain[] | [.stateHash,(.protocolState.consensusState.blockHeight|tonumber),(.protocolState.consensusState.slotSinceGenesis|tonumber),.commandTransactionCount + (.transactions.feeTransfer|length) + (if .transactions.coinbase == "0" then 0 else 1 end)>0] | join(",")'

blocks()
{ graphql "$1" "$blocks_query" | jq -r "$blocks_filter"
}

# Reads stream of blocks (ouput of blocks() command) and
# calculates maximum seen slot, along with hash/height/slot of
# a non-empty block with largest slot
latest_nonempty_block(){
  # data of a non-empty block with the largest slot
  latest_shash=""
  latest_height=0
  latest_slot=0

  max_slot=0

  # Read line by line, updating data above
  while read l; do
    IFS=, read -ra f <<< "$l"
    slot=${f[2]}
    non_empty="${f[3]}"
    if [[ $max_slot -lt $slot ]]; then
      max_slot=$slot
    fi
    if $non_empty && [[ $latest_slot -lt $slot ]]; then
      latest_shash="${f[0]}"
      latest_height=${f[1]}
      latest_slot=$slot
    fi
  done

  echo "$max_slot,$latest_shash,$latest_height,$latest_slot"
}

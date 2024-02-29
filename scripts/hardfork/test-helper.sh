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
      epoch
      stakingEpochData {
        ledger { hash }
        seed
      }
      nextEpochData {
        ledger { hash }
        seed
      }
    }
    blockchainState {
      stagedLedgerHash
      snarkedLedgerHash
    }
  }
  transactions {
    coinbase
    feeTransfer { fee }
  }
  stateHash
}
EOF
)"

blocks_filter='.data.bestChain[] |
  [ .stateHash
  , .protocolState.consensusState.blockHeight
  , .protocolState.consensusState.slotSinceGenesis
  , .commandTransactionCount + (.transactions.feeTransfer|length) + (if .transactions.coinbase == "0" then 0 else 1 end)>0
  , .protocolState.consensusState.stakingEpochData.ledger.hash
  , .protocolState.consensusState.stakingEpochData.seed
  , .protocolState.consensusState.nextEpochData.ledger.hash
  , .protocolState.consensusState.nextEpochData.seed
  , .protocolState.blockchainState.stagedLedgerHash
  , .protocolState.blockchainState.snarkedLedgerHash
  , .protocolState.consensusState.epoch
  ] | join(",")'

IX_STATE_HASH=0
IX_HEIGHT=1
IX_SLOT=2
IX_NON_EMPTY=3
IX_CUR_EPOCH_HASH=4
IX_CUR_EPOCH_SEED=5
IX_NEXT_EPOCH_HASH=6
IX_NEXT_EPOCH_SEED=7
IX_STAGED_HASH=8
IX_SNARKED_HASH=9
IX_EPOCH=10

blocks()
{ graphql "$1" "$blocks_query" | jq -r "$blocks_filter"
}

# Reads stream of blocks (ouput of blocks() command) and
# calculates/finds:
# 1. maximum seen slot
# 2. Latest snarked ledger hashes per-epoch
# 3. Latest non-empty block
# And returns the above as string
latest_nonempty_block(){
  # data of a non-empty block with the largest slot
  latest=( )
  latest[$IX_SLOT]=0

  # Latest snarked hashes per epoch
  snarked_hash_pe=()
  # Latest seen slot per epoch
  slot_pe=()

  max_slot=0

  # Read line by line, updating data above
  while read l; do
    IFS=, read -ra f <<< "$l"
    if [[ $max_slot -lt ${f[$IX_SLOT]} ]]; then
      max_slot=${f[$IX_SLOT]}
    fi
    if "${f[$IX_NON_EMPTY]}" && [[ ${latest[$IX_SLOT]} -lt ${f[$IX_SLOT]} ]]; then
      latest=( "${f[@]}" )
    fi
    epoch=${f[$IX_EPOCH]}
    if [[ "${slot_pe[$epoch]}" == "" ]] || [[ ${slot_pe[$epoch]} -lt ${f[$IX_SLOT]} ]]; then
      slot_pe[$epoch]=${f[$IX_SLOT]}
      snarked_hash_pe[$epoch]="${f[$IX_SNARKED_HASH]}"
    fi
  done
  latest_str="${latest[*]}"
  epochs="${!slot_pe[@]}"
  epoch_str="${epochs[*]}"
  snarked_hash_pe_str="${snarked_hash_pe[*]}"
  echo "$max_slot,${epoch_str//${IFS:0:1}/:},${snarked_hash_pe_str//${IFS:0:1}/:},${latest_str//${IFS:0:1}/,}"
}

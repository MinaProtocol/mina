set +x

function is_daemon_synced() {
    #
    # determine whether a local daemon is SYNCed with its network
    #

    status=$(
        curl -H "Content-Type:application/json" -d'{ "query": "query { syncStatus } " }' localhost:3085/graphql | \
            jq '.data.syncStatus'
    )
    
    [[ status == \"SYNCED\" ]] && return 0 || (echo "Daemon is out of sync with status: ${status}" && return 1) 
}

function is_chain_length_highest_received() {
    #
    # determine whether a local daemon is has processed the highest observed block
    #

    chainLength=$(
        curl -H "Content-Type:application/json" -d'{ "query": "query { daemonStatus { blockchainLength } }" }' localhost:3085/graphql | \
            jq '.data.daemonStatus.blockchainLength'
    )

    highestReceived=$(
        curl -H "Content-Type:application/json" -d'{ "query": "query { daemonStatus { highestBlockLengthReceived } }" }' localhost:3085/graphql | \
            jq '.data.daemonStatus.highestBlockLengthReceived'
    )
    
    [[ "${chainLength}" == "${highestReceived}" ]] && return 0 ||
        (echo "Daemon chain length[${chainLength}] is not at highest received[${highestReceived}]." && return 1) 
}

function peer_count_greater_than() {
    #
    # determine whether a local daemon has a peer count greater than some threshold
    #

    peerCountMinThreshold=$1
    peerCount=$(curl localhost:3085/graphql -d'{ query { daemonStatus { peers } } }')
    
    [[ $peerCount -gt $peerCountMinThreshold ]] && return 0 ||
        (echo "Peer count[${peerCount}] is not greater than mininum threshold[${peerCountMinThreshold}]." && return 1) 
}
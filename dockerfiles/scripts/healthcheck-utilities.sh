#
# Determine whether a local daemon is SYNCed with its network
#
function isDaemonSynced() {
    status=$(
        curl -H "Content-Type:application/json" -d'{ "query": "query { syncStatus } " }' localhost:3085/graphql | \
            jq '.data.syncStatus'
    )
    
    [[ status == \"SYNCED\" ]] && return 0 || (echo "Daemon is out of sync with status: ${status}" && return 1) 
}

#
# Determine whether a local daemon is has processed the highest observed block
#
function isChainlengthHighestReceived() {
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

#
# Determine whether a local daemon has a peer count greater than some threshold
#
function peerCountGreaterThan() {
    peerCountMinThreshold=${1:-2}
    peerCount=$(
        curl -H "Content-Type:application/json" -d'{ "query": "query { daemonStatus { peers } }" }' localhost:3085/graphql | \
            jq '.data.daemonStatus.peers | length'
    )
    
    [[ $peerCount -gt $peerCountMinThreshold ]] && return 0 ||
        (echo "Peer count[${peerCount}] is not greater than mininum threshold[${peerCountMinThreshold}]." && return 1) 
}

#
# Determine whether a local daemon owns a wallet account and has allocated funds
#
function ownsFunds() {
    ownedWalletCount=$(
        curl -H "Content-Type:application/json" -d'{ "query": "query { ownedWallets }" }' localhost:3085/graphql | \
            jq '.data.ownedWallets | length'
    )
    balanceTotal=$(
        curl -H "Content-Type:application/json" -d'{ "query": "query { ownedWallets { publicKey { balance { total } } } }" }' localhost:3085/graphql | \
            jq '.data.ownedWallets[].balance.total'
    )
    
    [[ $ownedWalletCount -gt 1 ]] && [[ $balanceTotal -gt 0 ]] && return 0 ||
        (echo "Owned wallet count[${ownedWalletCount}] and/or balance total[${peerCountMinThreshold}] is insufficient." && return 1) 
}

#
# Determine whether a local daemon process has sent sufficient user commands
#
function hasSentUserCommandsGreaterThan() {
    userCmdMinThreshold=${1:-1}
    userCmdSent=$(
        curl -H "Content-Type:application/json" -d'{ "query": "query { daemonStatus { userCommandsSent } }" }' localhost:3085/graphql | \
            jq '.data.daemonStatus.userCommandsSent'
    )
    
    [[ $userCmdSent -gt $userCmdMinThreshold ]] && return 0 ||
        (echo "User commands sent[${userCmdSent}] is not greater than mininum threshold[${userCmdMinThreshold}]." && return 1) 
}

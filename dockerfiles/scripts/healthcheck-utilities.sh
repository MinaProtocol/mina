#!/usr/bin/env bash

DAEMON_REST_PORT=${DAEMON_REST_PORT:=3085}

# Executes a GraphQL query and returns the result
# Parameters:
# $1 - The GraphQL query string
function queryGraphQL() {
    local query="$1"
        curl --silent --show-error \
            --header "Content-Type:application/json" \
        -d"{ \"query\": \"query { $query } \" }" \
        "localhost:${DAEMON_REST_PORT}/graphql"
}

# Retrieves a specific field from the daemon status
# Parameters:
# $1 - The field to retrieve from the daemon status
function getDaemonStatus() {
    local field="$1"
    queryGraphQL "daemonStatus { $field }" | jq ".data.daemonStatus.$field"
}

# Updates the sync status label of a Kubernetes pod
# Parameters:
# $1 - The app label of the pod to update
function updateSyncStatusLabel() {
    local status=$(queryGraphQL "syncStatus" | jq -r '.data.syncStatus')
    kubectl label --overwrite=true pod -l app=$1 syncStatus=${status}
}

# Checks if the daemon is synced
# Returns 0 if synced, 1 otherwise
function isDaemonSynced() {
    local status=$(queryGraphQL "syncStatus" | jq -r '.data.syncStatus')
    if [[ "$status" == "SYNCED" ]]; then
        return 0
    else
        echo "Daemon is out of sync with status: ${status}"
        return 1
    fi
}

# Checks if the current chain length matches the highest received block length
# Returns 0 if matched, 1 otherwise
function isChainlengthHighestReceived() {
    local chainLength=$(getDaemonStatus "blockchainLength")
    local highestReceived=$(getDaemonStatus "highestBlockLengthReceived")

    if [[ "${chainLength}" == "${highestReceived}" ]]; then
        return 0
    else
        echo "Daemon chain length[${chainLength}] is not at highest received[${highestReceived}]."
        return 1
    fi
}

# Checks if the peer count is greater than a specified threshold
# Parameters:
# $1 - The minimum threshold for peer count (default: 2)
# Returns 0 if peer count is above threshold, 1 otherwise
function peerCountGreaterThan() {
    local peerCountMinThreshold=${1:-2}
    local peerCount=$(getDaemonStatus "peers" | jq 'length')

    if [[ $peerCount -gt $peerCountMinThreshold ]]; then
        return 0
    else
        echo "Peer count[${peerCount}] is not greater than mininum threshold[${peerCountMinThreshold}]."
        return 1
    fi
}

# Checks if the daemon owns funds
# Returns 0 if the daemon has at least one wallet with a positive balance, 1 otherwise
function ownsFunds() {
    local ownedWalletCount=$(queryGraphQL "ownedWallets" | jq '.data.ownedWallets | length')
    local balanceTotal=$(queryGraphQL "ownedWallets { balance { total } }" | jq -r '.data.ownedWallets[0].balance.total')

    if [[ $ownedWalletCount -gt 0 ]] && [[ $balanceTotal -gt 0 ]]; then
        return 0
    else
        echo "Owned wallet count[${ownedWalletCount}] and/or balance total[${balanceTotal}] is insufficient."
        return 1
    fi
}

# Checks if the number of sent user commands is greater than a specified threshold
# Parameters:
# $1 - The minimum threshold for sent user commands (default: 1)
# Returns 0 if sent commands are above threshold, 1 otherwise
function hasSentUserCommandsGreaterThan() {
    local userCmdMinThreshold=${1:-1}
    local userCmdSent=$(getDaemonStatus "userCommandsSent")

    if [[ $userCmdSent -gt $userCmdMinThreshold ]]; then
        return 0
    else
        echo "User commands sent[${userCmdSent}] is not greater than mininum threshold[${userCmdMinThreshold}]."
        return 1
    fi
}

# Checks if the daemon has a snark worker
# Returns 0 if a snark worker is present, 1 otherwise
function hasSnarkWorker() {
    local snarkWorker=$(getDaemonStatus "snarkWorker")
    local rc=$?

    if [[ $rc == 0 ]] && [[ -n "$snarkWorker" ]]; then
        return 0
    else
        echo "Snark worker error: ${rc} - $snarkWorker"
        return 1
    fi
}

# Checks if the archive is synced with the local daemon
# Parameters:
# --db-host - The database host (default: localhost)
# --db-port - The database port (default: 5432)
# --db-user - The database user (default: postgres)
# --db-password - The database password (default: foobar)
# Returns 0 if the archive is synced, 1 otherwise
function isArchiveSynced() {
    local host="localhost"
    local port="5432"
    local user="postgres"
    local password="foobar"
    while [[ "$#" -gt 0 ]]; do
        case $1 in
        --db-host) host="$2"; shift;;
        --db-port) port="$2"; shift;;
        --db-user) user="$2"; shift;;
        --db-password) password="$2"; shift;;
        *) echo "Unknown parameter passed: $1"; exit 1;;
        esac
        shift
    done

    local highestObserved=$(PGPASSWORD=${password} psql -qtAX -h ${host} -p ${port} -d archive -U ${user} -w -c "SELECT height FROM blocks ORDER BY height DESC LIMIT 1")
    local highestReceived=$(getDaemonStatus "highestBlockLengthReceived")

    if [[ $highestObserved == $highestReceived ]]; then
        return 0
    else
        echo "Archive[${highestObserved}] is out of sync with local daemon[${highestReceived}]"
        return 1
    fi
}
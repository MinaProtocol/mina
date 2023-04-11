#!/usr/bin/env sh

set -e

usage() {
    cat <<EOF
Usage:
$0 <command> [<args> ...]
EOF
}

KUBECTL="kubectl"

frontend_port() {
    $KUBECTL get namespace/"$1" --output=jsonpath="{.metadata.annotations['openmina\.com/testnet\.nodePort']}"
}

mina_deployments() {
    $KUBECTL ${1:+--namespace=$1} get deployments -o json | \
        jq -r '.items[] | select( .spec.template.spec.containers | any( .name == "mina") ) | @text "deploy/\(.metadata.name)"'

}

mina_pods_ns() {
    if [ $# -eq 0 ]; then
        kubectl get pods -o json | \
            jq -r '.items[] | select( .spec.containers | any( .name == "mina") ) | @text "\(.metadata.name)"'
    else
        for NS in $*; do
            kubectl --namespace=$NS get pods -o json | \
                jq -r '.items[] | select( .spec.containers | any( .name == "mina") ) | @text "\(.metadata.namespace) \(.metadata.name)"'
        done
    fi
}

wait_for_job_status() {
    RESOURCE=$1
    TIMEOUT=$2
    kubectl wait --for=jsonpath='{.status.conditions[*].status}'=True "$RESOURCE" --timeout="$TIMEOUT"
    MSG=$(kubectl get "$RESOURCE" -o jsonpath='{.status.conditions[?(@.status=="True")].message}')
    TYPE=$(kubectl get "$RESOURCE" -o jsonpath='{.status.conditions[?(@.status=="True")].type}')
    if [ "${TYPE}" != "Complete" ]; then echo "Error running job: ${MSG}"; exit 1; fi
}

mina_exec() {
    RESOURCE=$1
    shift
    $KUBECTL exec "$RESOURCE" -c mina -- "$@"
}

mina_exec_ns() {
    RESOURCE=$1
    NS=$2
    shift 2
    $KUBECTL ${NS:+--namespace=$NS} exec "$RESOURCE" -c mina -- "$@"
}

mina_graphql_ns() {
    RESOURCE=$1
    NS=$2
    DATA="{\"query\": \"$3\"}"
    mina_exec_ns "$RESOURCE" $NS curl --silent --show-error --data "$DATA" --header "Content-Type:application/json" http://localhost:3085/graphql
}

mina_graphql() {
    RESOURCE=$1
    shift
    DATA="{\"query\": \"$*\"}"
    mina_exec "$RESOURCE" curl --silent --show-error --data "$DATA" --header "Content-Type:application/json" http://localhost:3085/graphql
}

mina_blockchain_height() {
    mina_graphql "$1" 'query { daemonStatus { highestBlockLengthReceived } }' | jq '.data.daemonStatus.highestBlockLengthReceived'
}

mina_node_chain_height() {
    mina_graphql "$1" 'query MyQuery {version bestChain(maxLength: 1) {protocolState {consensusState {blockHeight}}}}' | \
        jq -r '.data.bestChain[0].protocolState.consensusState.blockHeight'
}

mina_testnet_available() {
    TIMEOUT=$1
    shift
    if [ -z "$1" ]; then
        for NAME in $(mina_deployments); do
            $KUBECTL wait "$NAME" --for=condition=Available --timeout="$TIMEOUT" || exit 1
        done
    else
        for NS in $*; do
            for NAME in $(mina_deployments $NS); do
                $KUBECTL --namespace=$NS wait "$NAME" --for=condition=Available --timeout="$TIMEOUT" || exit 1
            done
        done
    fi
}

assert_mina_testnet_available() {
    if [ -z "$1" ]; then
        for NAME in $(mina_deployments); do
            $KUBECTL wait "$NAME" --for=condition=Available --timeout="60s" || exit 1
        done
    else
        for NS in $*; do
            for NAME in $(mina_deployments $NS); do
                $KUBECTL --namespace=$NS wait "$NAME" --for=condition=Available --timeout="60s" || exit 1
            done
        done
    fi
}

mina_testnet_available_ns() {
    TIMEOUT=$1
    for NAME in $(mina_pods_ns $*); do
        $KUBECTL wait "$NAME" --for=condition=Ready --timeout="$TIMEOUT" || exit 1
    done
}

mina_block_params() {
    mina_graphql_ns $1 $2 'query MyQuery {bestChain(maxLength: 1) {protocolState {consensusState {blockHeight} previousStateHash} stateHash}} ' | \
        jq -r '.data.bestChain[0] | @text "\(.stateHash) \(.protocolState.previousStateHash) \(.protocolState.consensusState.blockHeight)"'
}

mina_testnet_same_block_() {
    mina_pods_ns $* | {
        PREV_HEIGHT=""
        PREV_HASH=""
        while read NAMESPACE POD; do
            mina_block_params $POD $NAMESPACE | {
                read HASH PHASH HEIGHT
                if [ -z "$HEIGHT" ]; then
                    echo "$POD did not respond height"
                    exit 1
                fi
                echo "$POD is at $HEIGHT, hash is $HASH"
                if [ "$HEIGHT" -eq 1 ]; then
                    echo "Genesis block"
                    exit 1
                elif [ -z "$PREV_HEIGHT" ]; then
                    PREV_HEIGHT="${HEIGHT}"
                    PREV_HASH="${HASH}"
                elif [ "$HEIGHT" -eq "$PREV_HEIGHT" ]; then
                    if [ "$HASH" = "$PREV_HASH" ]; then
                        continue
                    else
                        echo "Height is the same but hash mismatch"
                        exit 1
                    fi
                elif [ "$HEIGHT" -eq "$((PREV_HEIGHT + 1))" ]; then
                    echo "Height increased by one, expected previous hash is $PREV_HASH"
                    if [ "$PHASH" = "$PREV_HASH" ]; then
                        PREV_HEIGHT=$HEIGHT
                        PREV_HASH=$HASH
                        continue
                    else
                        echo "Previous hash mismatch"
                        exit 1
                    fi
                else
                    echo "Height is different, $PREV_HEIGHT vs $HEIGHT"
                    return 1
                fi
            }
        done
    }
}

mina_testnet_same_height_() {
    PREV_HEIGHT=""
    for NAME in $(mina_deployments); do
        HEIGHT="$(mina_blockchain_height "$NAME")" #
        if [ -z "$HEIGHT" ]; then
            echo "$NAME did not respond height"
            return 1
        fi
        echo "$NAME is at $HEIGHT"
        if [ "$HEIGHT" -eq 1 ]; then
            echo "Genesis block"
            return 1
        elif [ -z "$PREV_HEIGHT" ]; then
            PREV_HEIGHT="${HEIGHT}"
        elif [ "$HEIGHT" -eq "$PREV_HEIGHT" ]; then
            continue
        elif [ "$HEIGHT" -eq "$((PREV_HEIGHT + 1))" ]; then
            echo "Height increased by one"
            PREV_HEIGHT="${HEIGHT}"
        else
            echo "Height is different, $PREV_HEIGHT vs $HEIGHT"
            return 1
        fi
    done
}

mina_testnet_same_height() {
    RETRIES="$1"
    PERIOD="$2"
    for _ in $(seq "$RETRIES"); do
        echo "Checking testnet height..."
        if mina_testnet_same_height_; then
            exit
        else
            echo "Retrying in ${PERIOD}s"
            sleep "$PERIOD"
        fi
    done
    exit 1
}

mina_testnet_same_chain() {
    RETRIES="$1"
    PERIOD="$2"
    shift 2
    for _ in $(seq "$RETRIES"); do
        echo "Checking testnet height..."
        if mina_testnet_same_block_ $*; then
            exit
        else
            echo "Retrying in ${PERIOD}s"
            sleep "$PERIOD"
        fi
    done
    exit 1
}

mina_node_epoch() {
    mina_graphql $1 'query MyQuery {bestChain(maxLength: 1) {protocolState {consensusState {epoch}}}}' | \
         jq -r '.data.bestChain[0].protocolState.consensusState.epoch'
}

mina_node_slot() {
    mina_graphql $1 'query MyQuery {bestChain(maxLength: 1) {protocolState {consensusState {slot}}}}' | \
         jq -r '.data.bestChain[0].protocolState.consensusState.slot'
}

mina_node_epoch_slot() {
    mina_graphql_ns $1 $2 'query MyQuery {bestChain(maxLength: 1) {protocolState {consensusState {epoch slot}}}}' | \
         jq -r '.data.bestChain[0].protocolState.consensusState | @text "\(.epoch) \(.slot)"'
}

mina_wait_for_epoch_slot() {
    RES=$1
    NS=$2
    TEPOCH=$3
    TSLOT=$4
    while true; do
        SLOT_EPOCH=$(mina_node_epoch_slot $RES $NS)
        EPOCH=${SLOT_EPOCH%% *}
        SLOT=${SLOT_EPOCH##* }
        echo "epoch $EPOCH, slot $SLOT"
        if [ $EPOCH -gt $TEPOCH ]; then
            exit
        elif [ $EPOCH -eq $TEPOCH ]; then
            if [ $SLOT -ge $TSLOT ]; then
                exit
            fi
        fi
        echo Waiting...
        sleep 10
    done
}

mina_node_history() {
    mina_graphql_ns $1 $2 'query MyQuery {bestChain(maxLength: 5) {protocolState {consensusState {blockHeight}} stateHash}} ' | \
         jq -r '.data.bestChain | [ [ .[0].protocolState.consensusState.blockHeight ], ( . | map( .stateHash )) ] | flatten | .[]'
}

assert_different_history() {
    RES1=$1
    NS1=$2
    RES2=$3
    NS2=$4
    HASH1=$(mina_graphql_ns $RES1 $NS1 'query {bestChain(maxLength: 1) {stateHash}}' | jq -r '.data.bestChain[0].stateHash')
    HASH2=$(mina_graphql_ns $RES2 $NS2 'query {bestChain(maxLength: 1) {stateHash}}' | jq -r '.data.bestChain[0].stateHash')
    R1=$(mina_graphql_ns $RES2 $NS2 "query {block(stateHash: \\\"$HASH1\\\") {stateHash}}" | jq -r '.data')
    R2=$(mina_graphql_ns $RES1 $NS1 "query {block(stateHash: \\\"$HASH2\\\") {stateHash}}" | jq -r '.data')
    if [ "$R1" != null ]; then
        echo "Block both segments share block $HASH1"
        exit 1
    elif [ "$R2" != null ]; then
        echo "Block both segments share block $HASH2"
        exit 1
    fi
    echo "Diverged history detected: blocks $HASH1 and $HASH2 belong to different branches"
}

CMD=$1
shift

if [ -z "$CMD" ]; then
    usage
    exit 1
fi

case "$CMD" in
    "frontend-port")        frontend_port "$@" ;;
    "mina-deployments")     mina_deployments ;;
    "mina-pods-ns")         mina_pods_ns $* ;;
    "mina-pods")            mina_pods_ns $* ;;
    "wait-for-job-status")  wait_for_job_status "$@" ;;
    "mina-exec")            mina_exec "$@" ;;
    "mina-graphql")         mina_graphql "$@" ;;
    "mina-testnet-available")
                            mina_testnet_available "$@" ;;
    "assert-mina-testnet-available")
                            assert_mina_testnet_available "$@" ;;
    "mina-testnet-same-height")
                            mina_testnet_same_height "$@" ;;
    "mina-testnet-same-chain")
                            mina_testnet_same_chain "$@" ;;
    "mina-node-max-height") mina_blockchain_height "$@" ;;
    "mina-node-chain-height")
                            mina_node_chain_height "$@" ;;
    "mina-node-global-slot")
                            mina_node_global_slot "$@" ;;
    "mina-node-epoch")      mina_node_epoch "$@" ;;
    "mina-node-epoch-slot") mina_node_epoch_slot "$@" ;;
    "mina-node-wait-for-epoch-slot")
                            mina_wait_for_epoch_slot "$@" ;;
    "mina-node-history")    mina_node_history $* ;;
    "assert-different-history")
                            assert_different_history $* ;;
    *)
        echo "No such command $CMD"
        usage
        exit 1
    ;;
esac

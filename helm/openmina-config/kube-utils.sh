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
    $KUBECTL get deployments -o json | \
        jq -r '.items[] | select( .spec.template.spec.containers | any( .name == "mina") ) | .metadata.name'

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

mina_graphql() {
    RESOURCE=$1
    shift
    DATA="{\"query\": \"$*\"}"
    mina_exec "$RESOURCE" curl --silent --show-error --data "$DATA" --header "Content-Type:application/json" http://localhost:3085/graphql
}

mina_blockchain_height() {
    mina_graphql "$1" 'query { daemonStatus { highestBlockLengthReceived } }' | jq '.data.daemonStatus.highestBlockLengthReceived'
}

mina_testnet_available() {
    TIMEOUT=$1
    for NAME in $(mina_deployments); do
        $KUBECTL wait "deployment/$NAME" --for=condition=Available --timeout="$TIMEOUT" || exit 1
    done
}

mina_testnet_same_height_() {
    PREV_HEIGHT=""
    for NAME in $(mina_deployments); do
        HEIGHT="$(mina_blockchain_height "deployment/$NAME")" #
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

CMD=$1
shift

if [ -z "$CMD" ]; then
    usage
    exit 1
fi

case "$CMD" in
    "frontend-port")        frontend_port "$@" ;;
    "mina-deployments")     mina_deployments ;;
    "wait-for-job-status")  wait_for_job_status "$@" ;;
    "mina-exec")            mina_exec "$@" ;;
    "mina-graphql")         mina_graphql "$@" ;;
    "mina-testnet-available")
                            mina_testnet_available "$@" ;;
    "mina-testnet-same-height")
                            mina_testnet_same_height "$@" ;;
    *)
        echo "No such command $CMD"
        usage
        exit 1
    ;;
esac

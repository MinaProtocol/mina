#!/usr/bin/env sh

set -e

. "$(dirname "$0")/common.sh"

if [ -z "$CHARTS" ]; then
    CHARTS="$(charts)"
fi
FRONTEND_CHART="$CHARTS/openmina-frontend"

usage() {
    cat <<EOF
Updates Openmina frontend according to nodes deployments.

Usage: $0 --namespace=NAMESPACE

Options:
   -h, --help       Display this message
   -n, --namespace=NAMESPACE
                    Use namespace NAMESPACE
   -p, --node-port=PORT
                    Use PORT as a node port to access the deployed frontend
   -i, --image=IMAGE
                    Specify frontend image to use
EOF
}

TEMP=$(getopt -o 'hn:i:p:' --long 'help,namespace:,image:,port:,node-port:' -n "$0" -- "$@")

if [ $? -ne 0 ]; then
	echo 'Terminating...' >&2
	exit 1
fi

eval set -- "$TEMP"
unset TEMP


while true; do
    case "$1" in
        '-h'|'--help')
            usage
            exit 0
        ;;
        '-n'|'--namespace')
            NAMESPACE=$2
            shift 2
            continue
        ;;
        '-p'|'--port'|'--node-port')
            NODE_PORT=$2
            shift 2
            continue
        ;;
        '-i'|'--image')
            IMAGE=$2
            shift 2
            continue
        ;;
		'--')
			shift
			break
		;;
		*)
			echo 'Internal error!' >&2
			exit 1
		;;
    esac
done

if [ -z "$NAMESPACE" ]; then
    echo "'--namespace' is missing"
    exit 1
fi

KUBECTL="kubectl --namespace=$NAMESPACE"
HELM="helm --namespace=$NAMESPACE"

get_values_file() {
    SHA=$(echo "$*" | sha256sum -)
    echo "frontend-values-${SHA%% *}.yaml"
}

get_mina_deployments() {
    $KUBECTL get deployments -o json | \
        jq -r '.items[] | select( .spec.template.spec.containers | any( .name == "mina") ) | .metadata.name'
}

gen_values_yaml() {
    IMAGE=$1
    NODE_PORT=$2
    shift 2;
    cat <<EOF
frontend:
  ${IMAGE:+image: $IMAGE}
  nodePort: $NODE_PORT
  nodes:
EOF
    for NAME in "$@"; do
        cat <<EOF
  - $NAME
EOF
    done
}

generate_values() {
    PODS=$(get_mina_deployments)
    VALUES=$(get_values_file "$IMAGE" "$NODE_PORT" $PODS)
    if ! [ -f "$VALUES" ]; then
        echo "Generating new $VALUES" >&2
        gen_values_yaml "$IMAGE" "$NODE_PORT" $PODS > "$VALUES"
    else
        echo "Using existing $VALUES" >&2
    fi
    echo "$VALUES"
}

if [ -z "$NODE_PORT" ]; then
    NODE_PORT=$($KUBECTL get namespace/"$NAMESPACE" --output=jsonpath="{.metadata.annotations['openmina\.com/testnet\.nodePort']}")
fi

if [ -z "$NODE_PORT" ]; then
    NODE_PORT=$($KUBECTL get service/frontend-service --output="jsonpath={.spec.ports[0].nodePort}")
fi

if [ -z "$NODE_PORT" ]; then
    echo "Cannot determine frontend node port. Use '--node-port'."
    exit 1
fi

# if [ -z "$IMAGE" ]; then
#     IMAGE=$($KUBECTL get deployment/frontend --output=jsonpath='{.spec.template.spec.containers[0].image}')
#     if [ -z "$NODE_PORT" ]; then
#         echo "Cannot determine frontend image. Use '--image'."
#         exit 1
#     fi
# fi

COMMON_VALUES="$(values frontend)"
GENERATED_VALUES="$(generate_values)"
$HELM upgrade --install frontend "$FRONTEND_CHART" --values="$COMMON_VALUES" --values="$GENERATED_VALUES"
$KUBECTL scale deployment frontend --replicas=0
$KUBECTL scale deployment frontend --replicas=1

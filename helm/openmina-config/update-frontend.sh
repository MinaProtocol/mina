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
   -n, --namespace=<NAMESPACE>
                    Use namespace NAMESPACE
   -o, --other-namespace=NAMESPACE
                    Add nodes from namespace NAMESPACE too. Use multiple times to add nodes from other namespaces.
   -p, --node-port=PORT
                    Use PORT as a node port to access the deployed frontend
   -i, --image=IMAGE
                    Specify frontend image to use
EOF
}

TEMP=$(getopt -o 'hn:o:i:p:' --long 'help,namespace:,other-namespace:,image:,port:,node-port:' -n "$0" -- "$@")

if [ $? -ne 0 ]; then
	echo 'Terminating...' >&2
	exit 1
fi

eval set -- "$TEMP"
unset TEMP

OTHER_NAMESPACES=""

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
        '-o'|'--other-namespace')
            OTHER_NAMESPACES="$OTHER_NAMESPACES $2"
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

if [ -z $NAMESPACE ]; then
    NAMESPACE=$(kubectl_ns)
fi
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
    kubectl --namespace=$1 get deployments -o json | \
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
    for NS in "$NAMESPACE" $OTHER_NAMESPACES; do
        PODS=$(get_mina_deployments $NS)
        for NAME in $PODS; do
            cat <<EOF
  - name: $NAME
    namespace: $NS
EOF
        done
    done
}

generate_values() {
    VALUES="$(mktemp -d)/values.yaml"
    echo "Generating new $VALUES" >&2
    gen_values_yaml "$IMAGE" "$NODE_PORT" > "$VALUES"
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

if [ -z "$IMAGE" ]; then
    IMAGE=$($KUBECTL get deployment/frontend --output=jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null) || true
fi

COMMON_VALUES="$(values frontend)"
GENERATED_VALUES="$(generate_values)"
$HELM upgrade --install frontend "$FRONTEND_CHART" --values="$COMMON_VALUES" --values="$GENERATED_VALUES" ${IMAGE:+--set=frontend.image="${IMAGE}"} "$@"
$KUBECTL rollout restart deploy/frontend

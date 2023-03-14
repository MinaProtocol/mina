#!/usr/bin/env sh

set -e

. "$(dirname "$0")/common.sh"

HELM_ARGS=""

if [ -z "$CHARTS" ]; then
    CHARTS="$(charts)"
fi
SEED_NODE_CHART="$CHARTS/seed-node"
BLOCK_PRODUCER_CHART="$CHARTS/block-producer"
SNARK_WORKER_CHART="$CHARTS/snark-worker"
PLAIN_NODE_CHART="$CHARTS/plain-node"

TEMP=$(getopt -o 'hafspwdoP:n:li:' --long 'help,all,frontend,seeds,producers,snarkers,snark-workers,nodes,plain-nodes,optimized,port:,node-port:,namespace:,force,image:,mina-image:,dry-run' -n "$0" -- "$@")

if [ $? -ne 0 ]; then
	echo 'Terminating...' >&2
	exit 1
fi

eval set -- "$TEMP"
unset TEMP

usage() {
    cat <<EOF
Deploys/updates Openmina testnet.

Usage:
$0 deploy [OPTIONS]
$0 delete [OPTIONS]
$0 lint [OPTIONS]
$0 dry-run [OPTIONS]

Options:
   -h, --help       Display this message
   -n, --namespace NAMESPACE
                    Use k8s namespace NAMESPACE
   -o, --optimized  Enable optimizations for Mina daemon
   -i, --mina-image, --image
                    Use specific image for Mina instead of what specified in values/common.yaml
   -a, --all        Install all nodes and the frontend
   -s, --seeds      Install seed nodes
   -p, --producers  Install block producing nodes
   -w, --snark-workers
                    Install snark workers (and HTTP coordinator)
   -d, --nodes      Install plain nodes
   -f, --front-end  Install frontend
   -P, --node-port=PORT
                    Use PORT as a node port to access the deployed frontend
                    (if omitted, taken from the namespace annotations)
   -D, --delete     Deletes all node-related Helm releases
       --dry-run    Do not deploy, just print commands
       --force      Do not ask confirmations
EOF
}

while true; do
    case "$1" in
        '-h'|'--help')
            usage
            exit 0
        ;;
        '-n'|'--namespace')
            NAMESPACE=$2
            shift 2;
            continue
        ;;
        '-i'|'--image'|'--mina-image')
            MINA_IMAGE=$2
            shift 2
            continue
        ;;
        '-a'|'--all')
            SEEDS=1
            PRODUCERS=1
            SNARK_WORKERS=1
            NODES=1
            FRONTEND=1
            shift
            continue
        ;;
        '-f'|'--frontend')
            FRONTEND=1
            shift
            continue
        ;;
        '-s'|'--seeds'|'--seed-nodes')
            SEEDS=1
            shift
            continue
        ;;
        '-p'|'--producers'|'--block-producers'|'--producer-nodes')
            PRODUCERS=1
            shift
            continue
        ;;
        '-w'|'--snarkers'|'--snark-workers')
            SNARK_WORKERS=1
            shift
            continue
        ;;
        '-d'|'--nodes'|'--plain-nodes')
            NODES=1
            shift
            continue
        ;;
        '-o'|'--optimized')
            HELM_ARGS="$HELM_ARGS --set=mina.optimized=true"
            OPTIMIZED=1
            shift
            continue
        ;;
        '-P'|'--port'|'--node-port')
            NODE_PORT=$2
            shift 2
            continue
        ;;
        '--force')
            FORCE=1
            shift
            continue
        ;;
        '--dry-run')
            DRY_RUN=1
            shift
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

if [ $# != 1 ]; then
    usage
    exit 1
fi

case $1 in
    'deploy'|'delete'|'lint')
        OP="$1"
    ;;
    *)
        echo "Unknown command $1"
        exit 1
    ;;
esac

KUBECTL_NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}')
if [ -z "$NAMESPACE" ]; then
    echo "Using current namespace ${KUBECTL_NAMESPACE:-default}"
    if [ -z "$LINT" ] && [ -z "$DRY_RUN" ] && [ -z "$FORCE" ]; then
        echo "You are using current namespace ${KUBECTL_NAMESPACE:-default}. Continue? [y/N]"
        read -r CONFIRM
        if ! [ "$CONFIRM" = y ] && ! [ "$CONFIRM" = Y ]; then
            echo "Aborting deployment"
            exit 1
        fi
    fi
    NAMESPACE=${KUBECTL_NAMESPACE:-default}
fi

if [ "$NAMESPACE" = testnet ] && [ -z "$DRY_RUN" ]; then
    if [ -z "$FORCE" ]; then
        echo "ERRO: 'testnet' namespace shouldn't be used"
        exit 1
    else
        echo "WARN: 'testnet' namespace shouldn't be used. Continue? [y/N]"
        read -r CONFIRM
        if ! [ "$CONFIRM" = y ] && ! [ "$CONFIRM" = Y ]; then
            echo "Aborting deployment"
            exit 1
        fi
    fi
fi

HELM="helm --namespace=$NAMESPACE"
HELM_ARGS="--values=$(values common) \
           --set=frontend.nodePort=$NODE_PORT \
           --set-file=mina.runtimeConfig=$(resource daemon.json) \
           ${MINA_IMAGE:+--set=mina.image=${MINA_IMAGE}} \
           $HELM_ARGS"

operate() {
    NAME=$1
    shift
    case $OP in
        deploy)
            if [ -z "$DRY_RUN" ]; then
               $HELM upgrade --install "$NAME" "$@"
            else
               echo $HELM upgrade --install "$NAME" "$@"
            fi
        ;;
        lint)
            $HELM lint "$@"
        ;;
        delete)
            if [ -z "$DRY_RUN" ]; then
                $HELM delete "$NAME" --wait --timeout=1m || true
            else
                echo $HELM delete "$NAME"
            fi
        ;;
        *)
            echo "Internal error: $OP"
        ;;
    esac
}



if [ -n "$SEEDS" ]; then
    operate seeds $SEED_NODE_CHART $HELM_ARGS --values="$(values seed)"
fi

if [ -n "$PRODUCERS" ]; then
    operate producers $BLOCK_PRODUCER_CHART $HELM_ARGS --values="$(values producer)"
fi

if [ -n "$SNARK_WORKERS" ]; then
    operate snark-workers $SNARK_WORKER_CHART $HELM_ARGS  --values="$(values snark-worker)" --set-file=publicKey="$(resource key-99.pub)"
fi

if [ -n "$NODES" ]; then
    operate nodes $PLAIN_NODE_CHART $HELM_ARGS --values="$(values node)"
fi

if [ -n "$FRONTEND" ]; then
    if [ "$OP" = lint ]; then
        echo "WARN: Linting for frontend is not implemented"
    elif [ "$OP" = dry-run ]; then
        echo "$(dirname "$0")/update-frontend.sh" --namespace=$NAMESPACE --node-port=$NODE_PORT
    elif [ "$OP" = delete ]; then
        operate frontend --namespace=$NAMESPACE
    else
        "$(dirname "$0")/update-frontend.sh" --namespace=$NAMESPACE --node-port=$NODE_PORT
    fi
fi

if [ "$OP" != lint ] && [ "$KUBECTL_NAMESPACE" != "$NAMESPACE" ]; then
    echo "WARN: Current kubectl namespace '$KUBECTL_NAMESPACE' differs from '$NAMESPACE'"
fi

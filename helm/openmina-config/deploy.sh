#!/usr/bin/env sh

set -e

. "$(dirname "$0")/common.sh"

HELM_ARGS=""
SET_ARGS=""

if [ -z "$CHARTS" ]; then
    CHARTS="$(charts)"
fi
SEED_NODE_CHART="$CHARTS/seed-node"
BLOCK_PRODUCER_CHART="$CHARTS/block-producer"
SNARK_WORKER_CHART="$CHARTS/snark-worker"
PLAIN_NODE_CHART="$CHARTS/plain-node"

TEMP=$(getopt -o 'hafspwdoP:n:li:S:' --long 'help,all,frontend,seeds,producers,snarkers,snark-workers,nodes,plain-nodes,optimized,port:,node-port:,namespace:,force,image:,mina-image:,dry-run,values-dir:,suffix:' -n "$0" -- "$@")

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
$0 deploy [OPTIONS] [ -- [HELM-OPTIONS ...] ]
$0 delete [OPTIONS] [ -- [HELM-OPTIONS ...] ]
$0 lint [OPTIONS] [ -- [HELM-OPTIONS ...] ]
$0 dry-run [OPTIONS] [ -- [HELM-OPTIONS ...] ]

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
   -w, --snark-workers, --snarkers
                    Install snark workers (and HTTP coordinator)
   -d, --plain-nodes, --nodes
                    Install plain nodes
   -f, --frontend   Install frontend
   -P, --node-port=PORT
                    Use PORT as a node port to access the deployed frontend
                    (if omitted, taken from the namespace annotations)
       --values-dir <DIR>
                    Use YAML files located in DIR instead of $(values_dir)
   -S, --suffix <SUFFIX>
                    Append SUFFIX to the Helm release names (to allow several releases in one namespace)
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
        '--values-dir')
            VALUES_DIR=$2
            shift 2
            continue
        ;;
        '--suffix')
            SUFFIX=$2
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

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

case $1 in
    'deploy'|'install'|'delete'|'lint'|'template')
        OP="$1"
        shift
    ;;
    *)
        echo "Unknown command $1"
        exit 1
    ;;
esac

KUBECTL_NAMESPACE=$(kubectl_ns)
if [ -z "$NAMESPACE" ]; then
    echo "Using current namespace ${KUBECTL_NAMESPACE:-default}"
    if [ "$OP" != "lint" ] && [ -z "$DRY_RUN" ] && [ -z "$FORCE" ]; then
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

HELM="helm"
HELM_ARGS="--namespace=$NAMESPACE \
           --values=$(values common) \
           --set=frontend.nodePort=$NODE_PORT \
           --set-file=mina.runtimeConfig=$(resource daemon.json) \
           ${MINA_IMAGE:+--set=mina.image=${MINA_IMAGE}} \
           $HELM_ARGS"

operate() {
    NAME="$1${SUFFIX:-}"
    shift
    case $OP in
        deploy|upgrade)
            if [ -z "$DRY_RUN" ]; then
               $HELM upgrade --install "$NAME" "$@"
            else
               echo $HELM upgrade --install "$NAME" "$@"
            fi
        ;;
        install)
            if [ -z "$DRY_RUN" ]; then
               $HELM install "$NAME" "$@"
            else
               echo $HELM install "$NAME" "$@"
            fi
        ;;
        lint)
            $HELM lint "$@"
        ;;
        template)
            $HELM template "$NAME" "$@"
        ;;
        delete)
            if [ -z "$DRY_RUN" ]; then
                $HELM delete "$NAME" "--namespace=$NAMESPACE" --wait --timeout=1m || true
            else
                echo $HELM delete "--namespace=$NAMESPACE" "$NAME"
            fi
        ;;
        *)
            echo "Internal error: $OP"
        ;;
    esac
}



if [ -n "$SEEDS" ]; then
    operate seeds $SEED_NODE_CHART $HELM_ARGS --values="$(values seed)" "$@"
fi

if [ -n "$PRODUCERS" ]; then
    operate producers $BLOCK_PRODUCER_CHART $HELM_ARGS --values="$(values producer)" "$@"
fi

if [ -n "$SNARK_WORKERS" ]; then
    operate snark-workers $SNARK_WORKER_CHART $HELM_ARGS  --values="$(values snark-worker)" --set-file=publicKey="$(resource key-99.pub)" "$@"
fi

if [ -n "$NODES" ]; then
    operate nodes $PLAIN_NODE_CHART $HELM_ARGS --values="$(values node)" "$@"
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

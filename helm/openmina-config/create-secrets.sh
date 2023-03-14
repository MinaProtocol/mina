#!/usr/bin/env sh

set -e

usage() {
    cat <<EOF
Creates public/private key secrets from specified files.

Usage: $0 --namespace=NAMESPACE NAME=PRIVKEY-FILE ...

Where NAME is the name of the Secret resource, and the PRIVKEY-FILE is the path
to the private key (either libp2p or Mina privkey). Secret will have property
"key" specifying the private key, and "pub", containint public key.

Options:
   -h, --help       Display this message
   -n, --namespace=NAMESPACE
                    Use namespace NAMESPACE
EOF
}

TEMP=$(getopt -o 'hn:' --long 'help,namespace:' -n "$0" -- "$@")

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

for KEY in "$@"; do
    NAME=${KEY%%=*}
    KEY=${KEY#*=}
    if [ "$KEY" = "$NAME" ]; then
        NAME=$(basename "$KEY")
    fi
    if [ -f "$KEY.pub" ]; then
        PUB="$KEY.pub"
    elif [ -f "$KEY.peerid" ]; then
        PUB="$KEY.peerid"
    else
        echo "WARN: no public key for $KEY"
        continue
    fi
    kubectl create --namespace="$NAMESPACE" secret generic "$NAME" --from-file=key="$KEY" --from-file=pub="$PUB"
done

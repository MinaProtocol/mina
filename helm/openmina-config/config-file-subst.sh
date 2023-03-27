#!/usr/bin/env sh

. $(dirname $0)/common.sh

TEMP=$(getopt -o 'ht:e:m:s:' --long 'help,timestamp:,blocks-per-epoch:,block-duration-ms:,block-duration:' -n "$0" -- "$@")

if [ $? -ne 0 ]; then
    echo 'Terminating...' >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

export TIMESTAMP=$(date -u -Isecond | sed -e 's/:..+/:00+/')
export SLOTS_PER_EPOCH=3000
export BLOCK_DURATION_MS=60000
INPUT=${INPUT:-$(resources)/daemon.template.json}
OUTPUT=${OUTPUT:-$(resources)/daemon.json}

while true; do
    case $1 in
        '-h'|'--help')
            usage
            exit
        ;;
        '-t'|'--timestamp')
            TIMESTAMP=$(date -u -Isecond -d $2)
            if [ $? -ne 0 ]; then
                exit 1
            fi
            shift 2
        ;;
        '-e'|'--blocks-per-epoch')
            export SLOTS_PER_EPOCH=$2
            shift 2
        ;;
        '-m'|'--block-duration-ms')
            BLOCK_DURATION_MS=$2
            shift 2
        ;;
        '-s'|'--block-duration')
            BLOCK_DURATION_MS=$(($2 * 1000))
            shift 2
        ;;
        '--')
            shift
            break
        ;;
        *)
            echo "Internal error: unknown option '$1'"
            exit 100
        ;;
    esac
done

envsubst < "$INPUT" > "$OUTPUT"

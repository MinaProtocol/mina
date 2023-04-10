#!/usr/bin/env sh

. $(dirname $0)/common.sh

TEMP=$(getopt -o 'ht:e:m:s:b:B:A:v:' --long 'help,timestamp:,slots-per-epoch:,slot-duration-ms:,slot-duration:,high-balance:,balance:,high-balance-accounts:,value:' -n "$0" -- "$@")

if [ $? -ne 0 ]; then
    echo 'Terminating...' >&2
    exit 1
fi

eval set -- "$TEMP"
unset TEMP

TIMESTAMP=$(date -u -Isecond | sed -e 's/:..+/:00+/')
HIGH_BALANCE=1000000000
LOW_BALANCE=100000
HIGH_BALANCE_ACCOUNTS=3
OUTPUT=${OUTPUT:-$(resources)/daemon.json}
DEFAULT_ACCOUNTS=$(resource test-accounts.json)
TEMPLATE=$(resource daemon.template.json)

usage() {
    cat <<EOF

    Usage: $0 [OPTIONS...] [<ACCOUNTS>]

    Generates Mina configuration file (daemon.json) with specified properties
    and genesis accounts. Accounts are taken from <ACCOUNTS> file, or from
    $DEFAULT_ACCOUNTS if omitted.

    Options:

    -h, --help      Display this message
    -t, --timestamp <TIME>
                    Use specified time for genesis timestamp instead of now
    -e, --slots-per-epoch <N>
                    The lenght of Mina epochs, in slots (should be divided by 3)
    -m, --slot-duration-ms <MILLIS>
                    Slot duration, in milliseconds
    -s, --slot-duration <SECONDS>
                    Slot duration, in seconds
    -B, --high-balance <NANO-MINA>
                    Balance for pumped-up accounts, used for block producing
    -b, --balance <NANO-MINA>
                    Balance for other accounts
    -A, --high-balance-accounts <N>
                    Number of pumped-up accounts
    -v, --value <VALUE-SPEC>
                    Value for arbitrary parameter
                    VALUE-SPEC should be a string in a form of '.obj1.obj2.obj3=JSON-VALUE'
EOF
}

FILTER='.'

while true; do
    case $1 in
        '-h'|'--help')
            usage
            exit
        ;;
        '-t'|'--timestamp')
            TIMESTAMP=$(date -u -Isecond -d "$2")
            if [ $? -ne 0 ]; then
                exit 1
            fi
            shift 2
        ;;
        '-e'|'--slots-per-epoch')
            if [ $(($2 % 3)) -ne 0 ]; then
                echo "Epoch lenght $2 cannot be divided by 3"
                exit 1
            fi
            FILTER="$FILTER | .genesis.slots_per_epoch = $2"
            shift 2
        ;;
        '-m'|'--slot-duration-ms')
            FILTER="$FILTER | .proof.block_window_duration_ms = $2"
            BLOCK_DURATION_MS=$2
            shift 2
        ;;
        '-s'|'--slot-duration')
            FILTER="$FILTER | .proof.block_window_duration_ms = $(($2 * 1000))"
            shift 2
        ;;
        '-B'|'--high-balance')
            HIGH_BALANCE=$2
            shift 2
        ;;
        '-b'|'--balance')
            LOW_BALANCE=$2
            shift 2
        ;;
        '-A'|'--high-balance-accounts')
            HIGH_BALANCE_ACCOUNTS=$2
            shift 2
        ;;
        '-v'|'--value')
            FILTER="$FILTER | $2"
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

ACCOUNTS=${1:-$DEFAULT_ACCOUNTS}

ACCS1=".[:$HIGH_BALANCE_ACCOUNTS] | map( . + { balance: \"$HIGH_BALANCE\" })"
ACCS2=".[$HIGH_BALANCE_ACCOUNTS:] | map( . + { balance: \"$LOW_BALANCE\" })"
FILTER="$FILTER | .genesis.genesis_state_timestamp = \"$TIMESTAMP\" | .ledger.accounts = (\$accounts[0] | (($ACCS1) + ($ACCS2)))"

jq --slurpfile accounts "$ACCOUNTS" "$FILTER" "$TEMPLATE"

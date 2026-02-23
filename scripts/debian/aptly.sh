#!/usr/bin/env bash

# bash strict mode
set -T # inherit DEBUG and RETURN trap for functions
set -C # prevent file overwrite by > &> <>
set -E # inherit -e
set -e # exit immediately on errors
set -u # exit on not assigned variables
set -o pipefail # exit on pipe failure

CLEAR='\033[0m'
RED='\033[0;31m'

# global variables
declare CLI_NAME='aptly.sh';
declare PS4='debug($LINENO) ${FUNCNAME[0]:+${FUNCNAME[0]}}(): ';

PORT=8080
# APTLY_ROOT can be set via environment to override default ~/.aptly
# This is useful for local builds where ~/.aptly may not be writable
APTLY_ROOT="${APTLY_ROOT:-$HOME/.aptly}"

# functions

function check_required() {
    if ! command -v "$1" >/dev/null 2>&1; then echo "Missing required program '$1' in PATH"; exit 1; fi
}
check_required aptly
check_required jq

function start_aptly() {
    local __distribution=$1
    local __debs=$2
    local __archs=$3
    local __background=$4
    local __clean=$5
    local __component=$6
    local __repo="${__distribution}"-"${__component}"
    local __port=$7
    local __wait=$8

    if [ "${__clean}" = 1 ]; then
        rm -rf "$APTLY_ROOT"
    fi

    # Create aptly config pointing to APTLY_ROOT if it doesn't use default
    mkdir -p "$APTLY_ROOT"
    APTLY_CONF="$APTLY_ROOT/aptly.conf"
    if [[ ! -f "$APTLY_CONF" ]]; then
        echo "{\"rootDir\": \"$APTLY_ROOT\"}" > "$APTLY_CONF"
    fi
    export APTLY_CONFIG="$APTLY_CONF"

    aptly -config="$APTLY_CONF" repo list | grep -q "^${__repo}$" && aptly -config="$APTLY_CONF" repo drop "${__repo}" || true

    aptly -config="$APTLY_CONF" repo create -component "${__component}" -distribution "${__distribution}" -architectures "${__archs}" "${__repo}"

    aptly -config="$APTLY_CONF" repo add -architectures "${__archs}" "${__repo}" "${__debs}"

    aptly -config="$APTLY_CONF" snapshot create -architectures "${__archs}" "${__component}" from repo "${__repo}"

    aptly -config="$APTLY_CONF" publish snapshot -architectures "${__archs}" -distribution "${__distribution}" -skip-signing "${__component}"

    if [ "${__background}" = 1 ]; then
        aptly -config="$APTLY_CONF" serve -listen 0.0.0.0:"${__port}" &
    else
        aptly -config="$APTLY_CONF" serve -listen 0.0.0.0:"${__port}"
    fi

    if [ $__wait = 1 ]; then
        local __timeout=300
        local __elapsed=0
        while ! curl -s "http://0.0.0.0:$__port" >/dev/null; do
            sleep 1
            __elapsed=$((__elapsed + 1))
            if [ $__elapsed -ge $__timeout ]; then
                echo "Error: Aptly debian repo did not start within 5 minutes."
                exit 1
            fi
        done
    fi
}


# cli

function start_help(){
    echo Start aptly server with input debians
    echo ""
    echo "     $CLI_NAME start [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    echo "  -b, --background  The Docker name (mina-devnet, mina-archive etc.)"
    echo "  -c, --codename    The Codename for debian repository"
    echo "  -d, --debians     The Debian(s) to be available in aptly. Supports regular expression"
    echo "  -m, --component   The Component for debian repository. For example: unstable"
    echo "  -l, --clean       Removes existing aptly installation"
    echo "  -p, --port        Server port. default=8080"
    echo "  -w, --wait        Wait for the server to start before exiting"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Example: $0  start --background --codename focal --debs *.deb --component unstable "
    echo ""
    exit 0
}

function start(){
    if [[ ${#} == 0 ]]; then
        start_help;
    fi

    local __distribution=""
    local __debs=""
    local __background=0
    local __clean=0
    local __component="unstable"
    local __archs="amd64"
    local __port=$PORT
    local __wait=0
    

    while [ ${#} -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help )
                start_help;
            ;;
            -b | --background )
                __background=1
                shift;
            ;;
            -c | --codename )
                __distribution=${2:?$error_message}
                shift 2;
            ;;
            -p | --port )
                __port=${2:?$error_message}
                shift 2;
            ;;
            -d | --debians )
                __debs=${2:?$error_message}
                shift 2;
            ;;
            -a | --archs )
                __archs=${2:?$error_message}
                shift 2;
            ;;
            -m | --component )
                __component=${2:?$error_message}
                shift 2;
            ;;
            -l | --clean )
                __clean=1
                shift;
            ;;
            -w | --wait )
                __wait=1
                shift;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                start_help;
            ;;
        esac
    done
    
    start_aptly $__distribution \
        $__debs \
        $__archs \
        $__background \
        $__clean \
        $__component \
        $__port \
        $__wait

}

function stop_help(){
    echo Stop running aptly server
    echo ""
    echo "     $CLI_NAME stop [-options]"
    echo ""
    echo "Parameters:"
    echo ""
    echo "  -c, --clean     Removes aptly installation"
    echo ""
    echo "Example: $0  stop --clean "
    echo ""
    exit 0
}

function stop(){

    local __clean=0

    while [ ${#} -gt 0 ]; do
        case $1 in
            -h | --help )
                stop_help;
            ;;
            -c | --clean )
                __clean=1
                shift;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                stop_help;
            ;;
        esac
    done

    pkill aptly || true
    if [ "${__clean}" = 1 ]; then
        rm -rf "$APTLY_ROOT"
    fi
}

function main_help(){
    echo Script for robust debian packages installation in CI
    echo ""
    echo "     $CLI_NAME [command] [-options]"
    echo ""
    echo "Commands:"
    echo ""
    printf "  %-23s %s\n" "help" "show help menu and commands";
    printf "  %-23s %s\n" "start" "start aptly deamon serving debian packages";
    printf "  %-23s %s\n" "stop" "stops and clean up aptly installation";
    echo ""
    exit "${1:-0}";
}

function main(){
    if (( ${#} == 0 )); then
        main_help 0;
    fi

    case ${1} in
        help )
            main_help 0;
        ;;
        start | stop )
            $1 "${@:2}";
        ;;
        * )
            echo -e "${RED} !! Unknown command: $1${CLEAR}\n";
            main_help 1;
        ;;
    esac
}

main "$@";

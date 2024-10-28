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

# functions

function check_required() {
    if ! command -v "$1" >/dev/null 2>&1; then echo "Missing required program '$1' in PATH"; exit 1; fi
}
check_required aptly
check_required jq
check_required gsutil


function start_aptly() {
    local __distribution=$1
    local __debs=$2
    local __background=$3
    local __clean=$4
    local __component=$5
    local __repo="${__distribution}"-"${__component}"
    local __port=$6

    if [ "${__clean}" = 1 ]; then
        rm -rf ~/.aptly
    fi

    aptly repo create -component "${__component}" -distribution "${__distribution}"  "${__repo}"

    aptly repo add "${__repo}" "${__debs}"

    aptly snapshot create "${__component}" from repo "${__repo}"

    aptly publish snapshot -distribution="${__distribution}" -skip-signing "${__component}"

    if [ "${__background}" = 1 ]; then
        aptly serve -listen localhost:"${__port}" &
    else
        aptly serve -listen localhost:"${__port}"
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
    echo "  -b, --background  The Docker name (mina, mina-archive etc.)"
    echo "  -c, --codename    The Codename for debian repository"
    echo "  -d, --debians     The Debian(s) to be available in aptly. Supports regular expression"
    echo "  -m, --component   The Component for debian repository. For example: unstable"
    echo "  -l, --clean       Removes existing aptly installation"
    echo "  -p, --port        Server port. default=8080"
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
    local __port=$PORT


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
            -m | --component )
                __component=${2:?$error_message}
                shift 2;
            ;;
            -l | --clean )
                __clean=1
                shift;
            ;;
            * )
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                start_help;
            ;;
        esac
    done

    start_aptly "${__distribution}" \
        "${__debs}" \
        "${__background}" \
        "${__clean}" \
        "${__component}" \
        "${__port}"


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

    pkill aptly
    if [ "${__clean}" = 1 ]; then
        rm -rf ~/.aptly
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

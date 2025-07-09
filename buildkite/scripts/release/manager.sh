#!/usr/bin/env bash

# Mina Release Manager - Refactored version
# Publish/Promote mina build artifacts to debian repository and docker registry

# bash strict mode
set -T # inherit DEBUG and RETURN trap for functions
set -C # prevent file overwrite by > &> <>
set -E # inherit -e
set -e # exit immediately on errors
set -u # exit on not assigned variables
set -o pipefail # exit on pipe failure

################################################################################
# Configuration and Setup
################################################################################

CLI_VERSION='1.0.0'
CLI_NAME="$0"
PS4='debug($LINENO) ${FUNCNAME[0]:+${FUNCNAME[0]}}(): '

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Source all library modules
source "$SCRIPTPATH/lib/common.sh"
source "$SCRIPTPATH/lib/storage.sh"
source "$SCRIPTPATH/lib/artifacts.sh"
source "$SCRIPTPATH/lib/validation.sh"
source "$SCRIPTPATH/lib/debian-utils.sh"
source "$SCRIPTPATH/lib/docker-utils.sh"

# Source all command modules
source "$SCRIPTPATH/commands/publish.sh"
source "$SCRIPTPATH/commands/promote.sh"
source "$SCRIPTPATH/commands/verify.sh"
source "$SCRIPTPATH/commands/fix.sh"
source "$SCRIPTPATH/commands/persist.sh"

# Import external scripts
source "$SCRIPTPATH/../../../scripts/debian/reversion-helper.sh"

################################################################################
# Main Functions
################################################################################

function main_help(){
    echo Publish/Promote mina build artifact.
    echo Script can publish build based on buildkite build id to debian
    echo repository and docker registry.
    echo "Script can also promote artifacts (debian packages and docker images)"
    echo "from one channel to another."
    echo ""
    echo "     $CLI_NAME [operation]"
    echo ""
    echo "Sub-commands:"
    echo ""
    echo " publish - publish build artifact to debian repository and"
    echo "           docker registry";
    echo " promote - promote artifacts from one channel (registry) to another";
    echo " fix - fix debian package repository";
    echo " verify - verify artifacts in target channel (registry)";
    echo " persist - persist artifacts from cache to storage";
    echo " version - show version";
    echo ""
    echo ""
    echo "Defaults: "
    echo " artifacts: $DEFAULT_ARTIFACTS"
    echo " networks: $DEFAULT_NETWORKS"
    echo " codenames: $DEFAULT_CODENAMES"
    echo " architecture: $DEFAULT_ARCHITECTURE"
    echo ""
    echo "Available values: "
    echo " artifacts: mina-logproc,mina-archive,mina-rosetta,mina-daemon"
    echo " networks: devnet,mainnet"
    echo " codenames: bullseye,focal"
    echo " channels: unstable,alpha,beta,stable"
    echo ""

    exit "${1:-0}";
}

function version(){
    echo $CLI_NAME $CLI_VERSION;
    exit 0
}

function main(){
    if (( ${#} == 0 )); then
        main_help 0;
    fi

    case ${1} in
        help )
            main_help 0;
        ;;
        version )
            version;
        ;;
        publish | promote | verify | fix | persist)
            $1 "${@:2}";
        ;;
        * )
            echo -e "${RED} !! Unknown command: $1${CLEAR}\n";
            main_help 1;
        ;;
    esac
}

main "$@";

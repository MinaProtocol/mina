#!/usr/bin/env bash

# Script for reading and writing files to/from global CI cache.
# Currently It uses cp as a cache manager and mounted shared hetzner storage.
# It supports read and write operations.
# It requires to be executed in buildkite context. e.g (BUILDKITE_BUILD_ID env var to be defined)

# bash strict mode
set -T # inherit DEBUG and RETURN trap for functions
set -C # prevent file overwrite by > &> <>
set -E # inherit -e
set -e # exit immediately on errors
set -u # exit on not assigned variables
set -o pipefail # exit on pipe failure


CLEAR='\033[0m'
RED='\033[0;31m'

################################################################################
# pre-setup
################################################################################

if [[ ! -v "BUILDKITE_BUILD_ID" ]]; then
    echo -e "${RED} Script must be invoked in Buildkite context: BUILDKITE_BUILD_ID must be set${CLEAR}"
    exit 1
fi

################################################################################
# global variable
################################################################################
# The version of the CLI
CLI_VERSION='1.0.0'
CLI_NAME="cache-manager"
PS4='debug($LINENO) ${FUNCNAME[0]:+${FUNCNAME[0]}}(): '

CACHE_BASE_URL="${CACHE_BASE_URL:-/var/storagebox}"

################################################################################
# functions
################################################################################

# Display the main help message
function main_help(){
    echo Read/Write file or files from/to CI cache.
    echo "Script requires to be executed in buildkite context. e.g (BUILDKITE_BUILD_ID env var to be defined)"
    echo ""
    echo "     $CLI_NAME [operation]"
    echo ""
    echo "Sub-commands:"
    echo ""
    echo " read - read file/files from cache";
    echo " write - write file/files to cache";
    echo " help - show this help message";
    echo ""
    exit "${1:-0}";
}

# Echo the version of the CLI
function version(){
    echo "$CLI_NAME" "$CLI_VERSION";
    exit 0
}

# Display the help message for the read command
function read_help(){
    echo "Read multiple files from CI cache into a local directory."
    echo "Script requires to be executed in buildkite context. e.g (BUILDKITE_BUILD_ID env var to be defined)"
    echo ""
    echo "     $CLI_NAME read [-options] INPUT_CACHE_LOCATION_1 [INPUT_CACHE_LOCATION_2 ...] OUTPUT_LOCAL_LOCATION"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "-o  | --override" "[bool] override existing cached files";
    printf "  %-25s %s\n" "-r  | --root" "[path] override cache root folder. Do not add leading slash at the beginning or end.";
    printf "  %-25s %s\n" "-s  | --skip-dirs-create" "[bool] skip creating local dirs";
    echo ""
    echo "Values:"
    echo ""
    echo " INPUT_CACHE_LOCATION_X - path(s) from which to read (copy) cached artifact(s) (supports wildcard)"
    echo " OUTPUT_LOCAL_LOCATION - local destination directory"
    echo ""
    echo "Example:"
    echo ""
    echo "  $CLI_NAME read debians/mina-devnet*.deb debians/mina-archive*.deb /workdir"
    echo ""
    echo " Above command will copy all matching files from CACHE_MOUNTPOINT/BUILDKITE_BUILD_ID/debians to /workdir"
    echo ""
    exit 0
}

# Read multiple files from the cache
function read(){
    if [[ "$#" == 0 ]]; then
        read_help;
    fi

    local __override=0
    local __root="$BUILDKITE_BUILD_ID"
    local __skip_dirs_creation=0
    local __inputs=()
    local __to=""

    while [ "$#" -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help )
                read_help;
            ;;
            -o | --override )
                __override=1
                shift 1;
            ;;
            -r | --root )
                __root=${2:?$error_message}
                shift 2;
            ;;
            -s | --skip-dirs-create )
                __skip_dirs_creation=1
                shift 1;
            ;;
            * )
                # Collect all but last argument as inputs
                if [[ "$#" -eq 1 ]]; then
                    __to="$1"
                    shift 1;
                    continue
                fi
                __inputs+=("$CACHE_BASE_URL/$__root/$1")
                shift 1;
            ;;
        esac
    done

    if [[ -z "$__to" ]]; then
        echo -e "${RED} !! Missing destination directory ('to')${CLEAR}\n";
        read_help;
    fi

    if [[ $__skip_dirs_creation == 1 ]]; then
        echo "..Skipping dirs creation"
    else
        mkdir -p "$__to"
    fi

    if ! test -d "$__to"; then
        echo -e "${RED} !! local location does not exist (or permission denied) : '$__to' ${CLEAR}\n";
        echo -e "${RED} HINT: allow to create local dirs disabling '--skip-dirs-create' ${CLEAR}\n";
        exit 1
    fi

    if [[ $__override == 1 ]]; then
        EXTRA_FLAGS=""
    else
        EXTRA_FLAGS="-f"
    fi

    for input_path in "${__inputs[@]}"; do
        echo "..Copying $input_path -> $__to"
        if ! cp -R ${EXTRA_FLAGS} $input_path "$__to"; then
            echo -e "${RED} !! There are some errors while copying files to cache. Exiting... ${CLEAR}\n";
            exit 2
        fi
    done
}

#==============
# write-many
#==============

# Display the help message for the write-many command
function write_help(){
    echo "Write multiple files to CI cache into a cache directory."
    echo "Script requires to be executed in buildkite context. e.g (BUILDKITE_BUILD_ID env var to be defined)"
    echo ""
    echo "     $CLI_NAME write-many [-options] INPUT_LOCAL_LOCATION_1 [INPUT_LOCAL_LOCATION_2 ...] OUTPUT_CACHE_LOCATION"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "-o  | --override" "[bool] override existing files";
    printf "  %-25s %s\n" "-r  | --root" "[path] override cache root folder. WARNING it does not override cache mount point. Do not add leading slash at the beginning or end.";
    echo ""
    echo "Values:"
    echo ""
    echo " INPUT_LOCAL_LOCATION_X - path(s) of files to write (supports wildcard)"
    echo " OUTPUT_CACHE_LOCATION - destination at cache mount"
    echo ""
    echo "Example:"
    echo ""
    echo "  $CLI_NAME write-many mina-devnet*.deb mina-archive*.deb debians/"
    echo ""
    echo " Above command will write all matching files to CACHE_MOUNTPOINT/BUILDKITE_BUILD_ID/debians"
    echo ""
    exit 0
}

# Write multiple files to the cache
function write(){
    if [[ "$#" == 0 ]]; then
        write_help;
    fi

    local __override=0
    local __root="$BUILDKITE_BUILD_ID"
    local __inputs=()
    local __to=""

    while [ "$#" -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help )
                write_help;
            ;;
            -o | --override )
                __override=1
                shift 1;
            ;;
            -r | --root )
                __root=${2:?$error_message}
                shift 2;
            ;;
            * )
                # Collect all but last argument as inputs
                if [[ "$#" -eq 1 ]]; then
                    __to=$CACHE_BASE_URL/$__root/"$1"
                    shift 1;
                    continue
                fi
                __inputs+=("$1")
                shift 1;
            ;;
        esac
    done

    if [[ -z "$__to" ]]; then
        echo -e "${RED} !! Missing destination directory ('to')${CLEAR}\n";
        write_help;
    fi

    if [[ $__override == 1 ]]; then
        EXTRA_FLAGS=""
    else
        EXTRA_FLAGS="-f"
    fi

    mkdir -p "$__to"

    for input_path in "${__inputs[@]}"; do
        echo "..Copying $input_path -> $__to"
        if ! cp -R ${EXTRA_FLAGS} $input_path "$__to"; then
            echo -e "${RED} !! There are some errors while copying files to cache. Exiting... ${CLEAR}\n";
            exit 2
        fi
    done
}
# Main function to handle the CLI
function main(){
    if (( "$#" == 0 )); then
        main_help 0;
    fi

    case ${1} in
        help )
            main_help 0;
        ;;
        read | write )
            $1 "${@:2}";
        ;;
        *)
            echo -e "${RED} !! Unknown command: $1 !!${CLEAR}\n";
            main_help 1;
        ;;
    esac
}

main "$@";
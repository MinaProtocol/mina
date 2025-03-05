#!/usr/bin/env bash

# Script for reading and writing files to/from local agent persistent storage.
# By default it uses /var/storagebox as a mount point.
# It requires to be executed in buildkite context. e.g (BUILDKITE_JOB_ID env var to be defined)

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

./buildkite/scripts/storage/env.sh

################################################################################
# global variable
################################################################################
CLI_VERSION='1.0.0';
CLI_NAME="$0";
PS4='debug($LINENO) ${FUNCNAME[0]:+${FUNCNAME[0]}}(): ';

################################################################################
# functions
################################################################################

function main_help(){
    echo Read/Write file or files from/to CI cache which is supposed to be mounted to buildkite-agent 
    echo "at '$CACHE_MOUNTPOINT'. Script requires to be executed in buildkite context. e.g (BUILDKITE_JOB_ID env var to be defined)".
    echo ""
    echo "     $CLI_NAME [operation]"
    echo ""
    echo "Sub-commands:"
    echo ""
    echo " read - read file/files from cache";
    echo " write - write file/files to cache";
    echo ""
    exit "${1:-0}";
}

function version(){
    echo $CLI_NAME $CLI_VERSION;
    exit 0
}

#========
# Read
#========

function read_help(){
    echo Read file or files from CI cache which is supposed to be mounted to buildkite-agent 
    echo "at '$CACHE_MOUNTPOINT'. Script requires to be executed in buildkite context. e.g (BUILDKITE_JOB_ID env var to be defined)".
    echo ""
    echo "     $CLI_NAME read [-options] INPUT_CACHE_LOCATION OUTPUT_LOCAL_LOCATION"
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "-o  | --override" "[bool] override existing cached files";
    printf "  %-25s %s\n" "-r  | --root" "[path] override cache root folder. WARNING it does not override cache mount point. Do not add leading slash at the beginning or end"; 
    echo ""
    echo "Values:"
    echo ""
    echo " INPUT_CACHE_LOCATION - path from which we will read (copy) cached artifact(s) (supports wildcard)"
    echo " OUTPUT_LOCAL_LOCATION - local destination"
    echo ""
    echo "Example:"
    echo ""
    echo "  " $CLI_NAME read  /workdir  debians/mina-devnet*.deb
    echo ""
    echo " Above command will copy 'debians/mina-devnet*.deb' files from CACHE_MOUNTPOINT/BUILDKITE_JOB_ID/debians to /workdir"
    echo ""
    echo ""
    exit 0
}

function read(){
    if [[ ${#} == 0 ]]; then
        read_help;
    fi

    local __override='-n'
    local __root="$CACHE_ROOT_FOLDER"
    local __skip_dirs_creation=0
      
    while [ ${#} -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help ) 
                read_help;
            ;;
            -o | --override )
               __override=''
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
                if [ ! -v __from ]; then
                   __from="$CACHE_MOUNTPOINT/$__root/$1"
                   shift 1;
                   continue
                fi
                
                if [ ! -v __to ]; then
                   __to="$1"
                   shift 1;
                   continue
                fi
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                read_help;
            ;;
        esac
    done
    

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

    echo "..Copying $__from -> $__to"

    if ! cp -r $__override $__from $__to ; then
        echo -e "${RED} !! There are some error while copying file to cache. Exiting... ${CLEAR}\n";
        exit 2
    fi
}


#==============
# write
#==============

function write_help(){
    echo Writes file to CI cache which is supposed to be mounted to buildkite-agent 
    echo "at '$CACHE_MOUNTPOINT'. Script requires to be executed in buildkite context. e.g (BUILDKITE_JOB_ID env var to be defined)".  
    echo ""
    echo "     $CLI_NAME write [-options] INPUT_LOCAL_LOCATION OUTPUT_CACHE_LOCATION"
    echo ""
    echo ""
    echo "Parameters:"
    echo ""
    printf "  %-25s %s\n" "-h  | --help" "show help";
    printf "  %-25s %s\n" "-g  | --override" "[bool] override existing files";
    printf "  %-25s %s\n" "-g  | --root" "[path] override cache root folder. WARNING it does not override cache mount point. Do not add leading slash at the beginning or end.";
    echo ""
    echo "Values:"
    echo ""
    echo " INPUT_LOCAL_LOCATION - single or multiple files to write (supports wildcard)"
    echo " OUTPUT_CACHE_LOCATION - destination at cache mount"
    echo ""
    echo "Example:"
    echo ""
    echo "  " $CLI_NAME write  mina-devnet*.deb debians/
    echo ""
    echo " Above command will write mina-devnet*.deb files to CACHE_MOUNTPOINT/BUILDKITE_JOB_ID/debians"
    echo ""
    echo ""
    exit 0
}


function write(){
    check_cache_exists

    if [[ ${#} == 0 ]]; then
        write_help;
    fi

    
    local __override='-n'
    local __root="$CACHE_ROOT_FOLDER"
      
    while [ ${#} -gt 0 ]; do
        error_message="Error: a value is needed for '$1'";
        case $1 in
            -h | --help ) 
                read_help;
            ;;
            -o | --override )
               __override=''
                shift 1;
            ;;
            -r | --root )
                __root=${2:?$error_message}
                shift 2;
            ;;
            * )
                if [ ! -v __from ]; then
                   __from="$1"
                   shift 1;
                   continue
                fi

                if [ ! -v __to ]; then
                   __to=$CACHE_MOUNTPOINT/$__root/"$1"
                   shift 1;
                   continue
                fi
                echo -e "${RED} !! Unknown option: $1${CLEAR}\n";
                echo "";
                read_help;
            ;;
        esac
    done
    
    if ! test -d "$__to"; then
        echo ".. Cache folder does not exist : '$__to'. Creating ";
        mkdir -p "$__to"
    fi

    echo "..Copying $__from -> $__to"
    
    if ! cp -r $__override $__from $__to ; then
        echo -e "${RED} !! There are some error while copying file to cache. Exiting... ${CLEAR}\n";
        exit 2
    fi
}

function main(){
    if (( ${#} == 0 )); then
        main_help 0;
    fi

    case ${1} in
        help )
            main_help 0;
        ;;
        read | write )
            $1 "${@:2}";
        ;;
        * )
            echo -e "${RED} !! Unknown command: $1${CLEAR}\n";
            main_help 1;
        ;;
    esac
}

main "$@";
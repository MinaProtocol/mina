#!/usr/bin/env bash

# Parameter validation utilities

function validate_required_param() {
    local param_name=$1
    local param_value=$2
    local help_function=$3

    if [[ -z ${param_value+x} ]]; then
        echo -e "❌ ${RED} !! ${param_name} is required${CLEAR}\n"
        $help_function
        exit 1
    fi
}

function validate_artifacts() {
    local artifacts=$1

    IFS=', '
    read -r -a artifacts_arr <<< "$artifacts"

    for artifact in "${artifacts_arr[@]}"; do
        case $artifact in
            mina-logproc|mina-archive|mina-rosetta|mina-daemon)
                # Valid artifact
                ;;
            *)
                echo -e "❌ ${RED} !! Unknown artifact: $artifact${CLEAR}\n"
                echo "Valid artifacts: mina-logproc,mina-archive," \
                     "mina-rosetta,mina-daemon"
                exit 1
                ;;
        esac
    done
}

function validate_networks() {
    local networks=$1

    IFS=', '
    read -r -a networks_arr <<< "$networks"

    for network in "${networks_arr[@]}"; do
        case $network in
            devnet|mainnet)
                # Valid network
                ;;
            *)
                echo -e "❌ ${RED} !! Unknown network: $network${CLEAR}\n"
                echo "Valid networks: devnet,mainnet"
                exit 1
                ;;
        esac
    done
}

function validate_codenames() {
    local codenames=$1

    IFS=', '
    read -r -a codenames_arr <<< "$codenames"

    for codename in "${codenames_arr[@]}"; do
        case $codename in
            bullseye|focal)
                # Valid codename
                ;;
            *)
                echo -e "❌ ${RED} !! Unknown codename: $codename${CLEAR}\n"
                echo "Valid codenames: bullseye,focal"
                exit 1
                ;;
        esac
    done
}

function validate_channel() {
    local channel=$1

    case $channel in
        unstable|alpha|beta|stable)
            # Valid channel
            ;;
        *)
            echo -e "❌ ${RED} !! Unknown channel: $channel${CLEAR}\n"
            echo "Valid channels: unstable,alpha,beta,stable"
            exit 1
            ;;
    esac
}

function validate_environment() {
    local backend=$1
    local verify=$2

    if [[ $backend == "gs" ]]; then
        check_gsutil
    fi

    if [[ $verify == 1 ]]; then
        check_docker
    fi
}
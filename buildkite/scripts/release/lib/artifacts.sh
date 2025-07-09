#!/usr/bin/env bash

# Artifact naming and versioning utilities

function get_suffix() {
    local __artifact=$1
    local __network="${2:-""}"

    case $__artifact in
        mina-daemon)
            echo "-$__network"
        ;;
        mina-rosetta)
            echo "-$__network"
        ;;

        *)
            echo ""
        ;;
    esac
}

function get_artifact_with_suffix() {
    local __artifact=$1
    local __network="${2:-""}"

    case $__artifact in
        mina-daemon)
            echo "mina-$__network"
        ;;
        mina-rosetta)
            echo "mina-rosetta-$__network"
        ;;

        *)
            echo "$__artifact"
        ;;
    esac
}

function get_repo() {
    local __publish_to_docker_io="$1"

    if [[ $__publish_to_docker_io == 1 ]]; then
        echo $DOCKER_IO_REPO
    else
        echo $GCR_REPO
    fi
}

function calculate_debian_version() {
    local __artifact=$1
    local __target_version=$2
    local __codename=$3
    local __network=$4

    local __network_suffix=$(get_suffix $__artifact $__network)
    echo "$__artifact:$__target_version-$__codename$__network_suffix"
}

function calculate_docker_tag() {
    local __publish_to_docker_io=$1
    local __artifact=$2
    local __target_version=$3
    local __codename=$4
    local __network=$5

    local __network_suffix=$(get_suffix $__artifact $__network)

    if [[ $__publish_to_docker_io == 1 ]]; then
        echo "$DOCKER_IO_REPO/$__artifact:$__target_version-" \
             "$__codename$__network_suffix"
    else
        echo "$GCR_REPO/$__artifact:$__target_version-" \
             "$__codename$__network_suffix"
    fi
}

function combine_docker_suffixes() {
    local network=$1
    local __docker_suffix=$2

    if [[ -n "$__docker_suffix" ]]; then
        echo "-$network-$__docker_suffix"
    else
        echo "-$network"
    fi
}

# Artifact iteration helper
function for_each_artifact() {
    local callback=$1
    local artifacts=$2
    local networks=$3
    local codenames=$4
    shift 4
    local additional_args=("$@")

    IFS=', '
    read -r -a artifacts_arr <<< "$artifacts"
    read -r -a networks_arr <<< "$networks"
    read -r -a codenames_arr <<< "$codenames"

    for artifact in "${artifacts_arr[@]}"; do
        for codename in "${codenames_arr[@]}"; do
            case $artifact in
                mina-logproc)
                    "$callback" "$artifact" "" "$codename" \
                             "${additional_args[@]}"
                ;;
                mina-archive)
                    "$callback" "$artifact" "" "$codename" \
                             "${additional_args[@]}"
                ;;
                mina-rosetta|mina-daemon)
                    for network in "${networks_arr[@]}"; do
                        "$callback" "$artifact" "$network" "$codename" \
                                 "${additional_args[@]}"
                    done
                ;;
                *)
                    echo "❌ Unknown artifact: $artifact"
                    exit 1
                ;;
            esac
        done
    done
}